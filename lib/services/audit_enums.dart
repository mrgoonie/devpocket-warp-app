/// Audit-related enums for security compliance and monitoring

/// Audit event types for comprehensive logging
enum AuditEventType {
  connectionAttempt,
  commandExecution,
  fileTransfer,
  authentication,
  keyGeneration,
  keyImport,
  hostKeyUpdate,
  disconnection,
  securityWarning,
  securityViolation,
  systemEvent,
}

/// Audit export formats for compliance reporting
enum AuditExportFormat {
  json,
  csv,
  syslog,
}