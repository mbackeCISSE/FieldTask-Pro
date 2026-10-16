INSERT IGNORE INTO users (id,email,password_salt,password_hash,name,role,company,enabled) VALUES
('techfix-demo-1','techfix@demo.sn','2S0wWf2dkN0rU4l6Bgfp0w==','ZwhDJWoFwP6SNWwCdm1pqaWv6hDBrA6klqLNLBH8HJs=','Amadou Ndiaye','Technicien','TechFix',TRUE);

INSERT IGNORE INTO interventions (id,title,client,address,description,equipment,priority,status,due_at,latitude,longitude,notes) VALUES
('TF-2601','Panne routeur cœur','Sunu Telecom','Plateau, Dakar','Perte intermittente de connectivité sur le réseau principal.','Routeur Cisco ASR','urgent','pending','2026-10-13 09:00:00',14.6697,-17.4358,''),
('TF-2602','Maintenance groupe électrogène','Hôpital Fann','Fann Résidence, Dakar','Révision périodique et contrôle du démarrage automatique.','Groupe SDMO 80 kVA','high','inProgress','2026-10-13 14:00:00',14.6873,-17.4660,''),
('TF-2603','Remplacement onduleur','Teranga Data Center','Diamniadio, Dakar','Batteries en fin de vie détectées lors du dernier contrôle.','Onduleur APC 6 kVA','normal','pending','2026-10-14 10:00:00',14.7172,-17.1770,''),
('TF-2604','Inspection antenne relais','Sunu Telecom','Thiès, Sénégal','Vérifier les fixations et la qualité de la liaison radio.','Antenne 4G','low','completed','2026-10-11 11:00:00',14.7910,-16.9359,'');
