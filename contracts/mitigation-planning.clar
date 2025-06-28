;; Assessment Coordination Contract
;; Coordinates and manages risk assessments

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_ASSESSMENT_NOT_FOUND (err u301))
(define-constant ERR_INVALID_STATUS (err u302))
(define-constant ERR_ASSESSOR_NOT_QUALIFIED (err u303))

;; Assessment statuses
(define-constant STATUS_PENDING u1)
(define-constant STATUS_IN_PROGRESS u2)
(define-constant STATUS_COMPLETED u3)
(define-constant STATUS_REVIEWED u4)
(define-constant STATUS_APPROVED u5)

;; Data structures
(define-map assessments
  { assessment-id: uint }
  {
    risk-id: uint,
    assigned-assessor: principal,
    coordinator: principal,
    status: uint,
    start-date: uint,
    due-date: uint,
    completion-date: uint,
    assessment-type: (string-ascii 50),
    methodology: (string-ascii 100),
    scope: (string-ascii 200)
  }
)

(define-map assessment-results
  { assessment-id: uint }
  {
    findings: (string-ascii 1000),
    recommendations: (string-ascii 1000),
    risk-rating: uint,
    confidence-level: uint,
    evidence-quality: uint,
    reviewer: (optional principal),
    review-notes: (optional (string-ascii 500))
  }
)

(define-map assessment-timeline
  { assessment-id: uint, milestone: uint }
  {
    description: (string-ascii 100),
    planned-date: uint,
    actual-date: (optional uint),
    status: (string-ascii 20)
  }
)

(define-data-var next-assessment-id uint u1)

;; Public functions
(define-public (create-assessment
  (risk-id uint)
  (assigned-assessor principal)
  (due-date uint)
  (assessment-type (string-ascii 50))
  (methodology (string-ascii 100))
  (scope (string-ascii 200))
)
  (let ((assessment-id (var-get next-assessment-id))
        (current-time (unwrap-panic (get-block-info? time (- block-height u1)))))
    ;; TODO: Verify assessor is qualified (would call risk-assessor-verification contract)
    (map-set assessments
      { assessment-id: assessment-id }
      {
        risk-id: risk-id,
        assigned-assessor: assigned-assessor,
        coordinator: tx-sender,
        status: STATUS_PENDING,
        start-date: current-time,
        due-date: due-date,
        completion-date: u0,
        assessment-type: assessment-type,
        methodology: methodology,
        scope: scope
      }
    )
    (var-set next-assessment-id (+ assessment-id u1))
    (ok assessment-id)
  )
)

(define-public (start-assessment (assessment-id uint))
  (match (map-get? assessments { assessment-id: assessment-id })
    assessment-data
    (begin
      (asserts! (is-eq tx-sender (get assigned-assessor assessment-data)) ERR_UNAUTHORIZED)
      (asserts! (is-eq (get status assessment-data) STATUS_PENDING) ERR_INVALID_STATUS)
      (map-set assessments
        { assessment-id: assessment-id }
        (merge assessment-data { status: STATUS_IN_PROGRESS })
      )
      (ok true)
    )
    ERR_ASSESSMENT_NOT_FOUND
  )
)

(define-public (submit-assessment-results
  (assessment-id uint)
  (findings (string-ascii 1000))
  (recommendations (string-ascii 1000))
  (risk-rating uint)
  (confidence-level uint)
  (evidence-quality uint)
)
  (match (map-get? assessments { assessment-id: assessment-id })
    assessment-data
    (let ((current-time (unwrap-panic (get-block-info? time (- block-height u1)))))
      (asserts! (is-eq tx-sender (get assigned-assessor assessment-data)) ERR_UNAUTHORIZED)
      (asserts! (is-eq (get status assessment-data) STATUS_IN_PROGRESS) ERR_INVALID_STATUS)
      (map-set assessment-results
        { assessment-id: assessment-id }
        {
          findings: findings,
          recommendations: recommendations,
          risk-rating: risk-rating,
          confidence-level: confidence-level,
          evidence-quality: evidence-quality,
          reviewer: none,
          review-notes: none
        }
      )
      (map-set assessments
        { assessment-id: assessment-id }
        (merge assessment-data {
          status: STATUS_COMPLETED,
          completion-date: current-time
        })
      )
      (ok true)
    )
    ERR_ASSESSMENT_NOT_FOUND
  )
)

(define-public (review-assessment
  (assessment-id uint)
  (review-notes (string-ascii 500))
  (approved bool)
)
  (match (map-get? assessments { assessment-id: assessment-id })
    assessment-data
    (begin
      (asserts! (is-eq tx-sender (get coordinator assessment-data)) ERR_UNAUTHORIZED)
      (asserts! (is-eq (get status assessment-data) STATUS_COMPLETED) ERR_INVALID_STATUS)
      (match (map-get? assessment-results { assessment-id: assessment-id })
        results-data
        (begin
          (map-set assessment-results
            { assessment-id: assessment-id }
            (merge results-data {
              reviewer: (some tx-sender),
              review-notes: (some review-notes)
            })
          )
          (map-set assessments
            { assessment-id: assessment-id }
            (merge assessment-data {
              status: (if approved STATUS_APPROVED STATUS_REVIEWED)
            })
          )
          (ok approved)
        )
        ERR_ASSESSMENT_NOT_FOUND
      )
    )
    ERR_ASSESSMENT_NOT_FOUND
  )
)

;; Read-only functions
(define-read-only (get-assessment (assessment-id uint))
  (map-get? assessments { assessment-id: assessment-id })
)

(define-read-only (get-assessment-results (assessment-id uint))
  (map-get? assessment-results { assessment-id: assessment-id })
)

(define-read-only (get-assessments-by-assessor (assessor principal))
  ;; This would return a list of assessment IDs for the given assessor
  ;; Implementation would require iteration through all assessments
  (ok u0) ;; Placeholder
)

(define-read-only (get-next-assessment-id)
  (var-get next-assessment-id)
)
