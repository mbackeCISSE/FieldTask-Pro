package sn.techfix.fieldtask;

import org.springframework.boot.CommandLineRunner;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/** Adds the demo technician assignment to databases created before this feature. */
@Component
class InterventionAssignmentMigration implements CommandLineRunner {
  private final JdbcTemplate db;

  InterventionAssignmentMigration(JdbcTemplate db) {
    this.db = db;
  }

  @Override
  public void run(String... args) {
    Integer columnCount = db.queryForObject(
        "SELECT COUNT(*) FROM information_schema.COLUMNS " +
        "WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='interventions' AND COLUMN_NAME='technician_id'",
        Integer.class);
    if (columnCount != null && columnCount == 0) {
      db.execute("ALTER TABLE interventions ADD COLUMN technician_id VARCHAR(64) NOT NULL DEFAULT 'techfix-demo-1'");
    }
  }
}
