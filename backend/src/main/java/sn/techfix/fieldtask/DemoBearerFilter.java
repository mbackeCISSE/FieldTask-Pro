package sn.techfix.fieldtask;

import java.io.IOException;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/** Validates opaque bearer sessions stored as hashes in MySQL. */
@Component
class DemoBearerFilter extends OncePerRequestFilter {
  private final JdbcTemplate db;

  DemoBearerFilter(JdbcTemplate db) {
    this.db = db;
  }

  @Override
  protected boolean shouldNotFilter(HttpServletRequest request) {
    String path = request.getRequestURI();
    return "OPTIONS".equalsIgnoreCase(request.getMethod())
        || path.endsWith("/health")
        || path.endsWith("/auth/demo");
  }

  @Override
  protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
      throws ServletException, IOException {
    String authorization = request.getHeader("Authorization");
    if (authorization == null || !authorization.startsWith("Bearer ") ||
        authorization.length() <= "Bearer ".length()) {
      response.sendError(HttpServletResponse.SC_UNAUTHORIZED, "Session de démonstration invalide ou absente.");
      return;
    }
    String token = authorization.substring("Bearer ".length());
    List<Map<String,Object>> sessions=db.queryForList(
        "SELECT s.technician_id FROM auth_sessions s JOIN users u ON u.id=s.technician_id " +
        "WHERE s.token_hash=? AND s.expires_at>? AND u.enabled=TRUE",
        AuthenticationCrypto.tokenHash(token), java.sql.Timestamp.from(Instant.now()));
    if (sessions.isEmpty()) {
      response.sendError(HttpServletResponse.SC_UNAUTHORIZED, "Session expirée ou invalide.");
      return;
    }
    request.setAttribute("technicianId", String.valueOf(sessions.get(0).get("technician_id")));
    chain.doFilter(request, response);
  }
}
