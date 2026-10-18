// lib/features/payment/presentation/payment.dart

/// ✅ PaymentType enum — Job, Service, Scheme
/// - `job`     → payment_type="job",     application_type="job"
/// - `service` → payment_type="service", application_type="service"
/// - `scheme`  → payment_type="scheme",  application_type="schemes"
enum PaymentType {
  job,
  service,
  scheme,
}