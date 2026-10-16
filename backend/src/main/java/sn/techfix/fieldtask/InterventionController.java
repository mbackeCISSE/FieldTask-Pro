package sn.techfix.fieldtask;

import java.nio.file.*;
import java.security.SecureRandom;
import java.time.Duration;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.atomic.AtomicReference;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

@RestController @RequestMapping("/api") @CrossOrigin(origins="*")
class InterventionController {
  private static final SecureRandom SECURE_RANDOM = new SecureRandom();
  private final JdbcTemplate db;
  private final TransactionTemplate transactions;
  InterventionController(JdbcTemplate db, PlatformTransactionManager transactionManager) {
    this.db=db; this.transactions=new TransactionTemplate(transactionManager);
  }
  @GetMapping("/health") Map<String,Object> health(){return Map.of("status","UP","service","FieldTask Pro");}
  @PostMapping("/auth/demo") Map<String,Object> login(@RequestBody Map<String,String> body){
    String email=Optional.ofNullable(body.get("email")).orElse("").trim();
    String password=body.get("password");
    List<Map<String,Object>> matches=db.queryForList("SELECT * FROM users WHERE LOWER(email)=LOWER(?) AND enabled=TRUE",email);
    if(matches.isEmpty()||!AuthenticationCrypto.verifyPassword(password,
        String.valueOf(matches.get(0).get("password_salt")),
        String.valueOf(matches.get(0).get("password_hash")))) {
      throw new ResponseStatusException(HttpStatus.UNAUTHORIZED,"Adresse e-mail ou mot de passe incorrect.");
    }
    Map<String,Object> user=matches.get(0);
    byte[] tokenBytes=new byte[32];SECURE_RANDOM.nextBytes(tokenBytes);
    String accessToken=Base64.getUrlEncoder().withoutPadding().encodeToString(tokenBytes);
    Instant expiresAt=Instant.now().plus(Duration.ofHours(12));
    db.update("INSERT INTO auth_sessions(token_hash,technician_id,expires_at) VALUES(?,?,?)",
        AuthenticationCrypto.tokenHash(accessToken),user.get("id"),Timestamp.from(expiresAt));
    return Map.of("accessToken",accessToken,"tokenType","Bearer","expiresAt",expiresAt.toString(),
        "technician",Map.of("id",user.get("id"),"name",user.get("name"),"role",user.get("role"),"company",user.get("company")));
  }
  @PostMapping("/auth/logout") Map<String,Object> logout(@RequestHeader("Authorization") String authorization){
    db.update("DELETE FROM auth_sessions WHERE token_hash=?",AuthenticationCrypto.tokenHash(authorization.substring("Bearer ".length())));
    return Map.of("signedOut",true);
  }
  @GetMapping("/profile") Map<String,Object> profile(@RequestAttribute("technicianId") String technicianId){
    List<Map<String,Object>> rows=db.queryForList("SELECT id,name,role,company FROM users WHERE id=? AND enabled=TRUE",technicianId);
    if(rows.isEmpty())throw new ResponseStatusException(HttpStatus.NOT_FOUND,"Technicien introuvable.");
    return rows.get(0);
  }
  @GetMapping("/interventions") List<Map<String,Object>> list(@RequestAttribute("technicianId") String technicianId){return db.queryForList("SELECT * FROM interventions WHERE technician_id=? ORDER BY due_at",technicianId);}
  @GetMapping("/interventions/{id}") Map<String,Object> get(@PathVariable String id,@RequestAttribute("technicianId") String technicianId){return find(id,technicianId);}
  @GetMapping("/sync/changes") Map<String,Object> changes(@RequestParam(required=false) String since,@RequestAttribute("technicianId") String technicianId){
    Timestamp serverTime=db.queryForObject("SELECT CURRENT_TIMESTAMP",Timestamp.class);
    List<Map<String,Object>> rows;
    if(since==null||since.isBlank()) rows=db.queryForList("SELECT * FROM interventions WHERE technician_id=? ORDER BY updated_at",technicianId);
    else {
      Instant cursor;try{cursor=Instant.parse(since);}catch(Exception e){throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Curseur de synchronisation invalide.");}
      // MySQL timestamps use second precision by default. Re-read a short overlap
      // so updates sharing the cursor's second are not skipped; the client applies
      // each row idempotently and already protects locally pending work.
      rows=db.queryForList("SELECT * FROM interventions WHERE technician_id=? AND updated_at >= ? ORDER BY updated_at",technicianId,Timestamp.from(cursor.minusSeconds(2)));
    }
    List<Map<String,Object>> items=rows.stream().map(row->{
      Map<String,Object> item=new LinkedHashMap<>();item.put("id",row.get("id"));item.put("technicianId",row.get("technician_id"));item.put("title",row.get("title"));item.put("client",row.get("client"));
      item.put("address",row.get("address"));item.put("description",row.get("description"));item.put("equipment",row.get("equipment"));
      item.put("priority",row.get("priority"));item.put("status",row.get("status"));item.put("dueAt",asIso(row.get("due_at")));
      item.put("latitude",row.get("latitude"));item.put("longitude",row.get("longitude"));item.put("notes",row.get("notes"));item.put("updatedAt",asIso(row.get("updated_at")));return item;
    }).toList();
    return Map.of("changes",items,"cursor",serverTime.toInstant().toString());
  }
  @PutMapping("/interventions/{id}/status") Map<String,Object> status(@PathVariable String id,@RequestBody Map<String,String> body,@RequestAttribute("technicianId") String technicianId){
    Map<String,Object> current=find(id,technicianId);String from=String.valueOf(current.get("status")),to=body.get("status");
    boolean allowed=("pending".equals(from)&&"inProgress".equals(to))||("inProgress".equals(from)&&"completed".equals(to));
    if(!allowed)throw new ResponseStatusException(HttpStatus.CONFLICT,"Transition de statut invalide.");
    int changed=db.update("UPDATE interventions SET status=?,updated_at=CURRENT_TIMESTAMP WHERE id=? AND technician_id=? AND status=?",to,id,technicianId,from);
    if(changed==0)throw new ResponseStatusException(HttpStatus.CONFLICT,"Intervention modifiée simultanément.");
    return find(id,technicianId);
  }
  @PostMapping("/interventions/{id}/notes") Map<String,Object> note(@PathVariable String id,@RequestBody Map<String,String> body,@RequestAttribute("technicianId") String technicianId){
    String text=body.getOrDefault("note","").trim();if(text.isEmpty())throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"La note ne peut pas être vide.");
    find(id,technicianId);db.update("UPDATE interventions SET notes=CONCAT_WS(CHAR(10),NULLIF(notes,''),?),updated_at=CURRENT_TIMESTAMP WHERE id=? AND technician_id=?",text,id,technicianId);return find(id,technicianId);
  }
  @PostMapping("/sync/{operationId}") Map<String,Object> sync(@PathVariable String operationId,@RequestBody Map<String,Object> body,@RequestAttribute("technicianId") String technicianId){
    return transactions.execute(tx->{
      int inserted=db.update("INSERT IGNORE INTO sync_operations(operation_id,result_json) VALUES(?,?)",operationId,"{}");
      if(inserted==0)return Map.of("duplicate",true,"operationId",operationId);
      String id=String.valueOf(body.get("interventionId")),type=String.valueOf(body.get("type"));Map<String,Object> result;
      find(id,technicianId);
      if("status".equals(type))result=status(id,Map.of("status",String.valueOf(body.get("status"))),technicianId);
      else if("note".equals(type))result=note(id,Map.of("note",String.valueOf(body.get("note"))),technicianId);
      else throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Type d'opération inconnu.");
      return Map.of("duplicate",false,"operationId",operationId,"result",result);
    });
  }
  @PostMapping(value="/sync/{operationId}/attachment",consumes="multipart/form-data") Map<String,Object> attachment(
      @PathVariable String operationId,@RequestParam String interventionId,@RequestParam String kind,@RequestPart MultipartFile file,@RequestAttribute("technicianId") String technicianId){
    if(!Set.of("photo","signature").contains(kind))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Type de fichier invalide.");find(interventionId,technicianId);
    AtomicReference<Path> storedPath=new AtomicReference<>();
    try{
      Path directory=Path.of("uploads");Files.createDirectories(directory);
      String suffix=Optional.ofNullable(file.getOriginalFilename()).map(n->{int i=n.lastIndexOf('.');return i<0?".bin":n.substring(i).replaceAll("[^A-Za-z0-9.]","");}).orElse(".bin");
      String filename=operationId+suffix;
      Map<String,Object> result=transactions.execute(tx->{
        int inserted=db.update("INSERT IGNORE INTO sync_operations(operation_id,result_json) VALUES(?,?)",operationId,"{}");
        if(inserted==0)return Map.of("duplicate",true,"operationId",operationId);
        Path target=directory.resolve(filename);
        try{Files.copy(file.getInputStream(),target,StandardCopyOption.REPLACE_EXISTING);storedPath.set(target);}
        catch(Exception e){throw new IllegalStateException("Lecture du fichier transmis impossible.",e);}
        db.update("INSERT INTO attachments(id,intervention_id,kind,stored_name) VALUES(?,?,?,?)",operationId,interventionId,kind,filename);
        return Map.of("duplicate",false,"operationId",operationId,"stored",true);
      });
      return result;
    }catch(Exception e){try{if(storedPath.get()!=null)Files.deleteIfExists(storedPath.get());}catch(Exception ignored){}throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR,"Enregistrement du fichier impossible.");}
  }
  private Map<String,Object> find(String id,String technicianId){List<Map<String,Object>> rows=db.queryForList("SELECT * FROM interventions WHERE id=? AND technician_id=?",id,technicianId);if(rows.isEmpty())throw new ResponseStatusException(HttpStatus.NOT_FOUND,"Intervention introuvable.");return rows.get(0);}
  private String asIso(Object value){if(value instanceof Timestamp t)return t.toInstant().toString();if(value instanceof java.time.LocalDateTime d)return d.toString()+"Z";return String.valueOf(value);}
}
