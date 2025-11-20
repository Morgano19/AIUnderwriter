;; AI-Enhanced Health Insurance Underwriting Smart Contract
;; This contract implements an intelligent health insurance underwriting system that uses
;; AI-driven risk assessment to evaluate applicants, calculate premiums, and manage policies.
;; It includes features for policy issuance, claims processing, and dynamic premium adjustments.

;; constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-input (err u103))
(define-constant err-insufficient-funds (err u104))
(define-constant err-policy-expired (err u105))
(define-constant err-already-exists (err u106))
(define-constant err-claim-rejected (err u107))

;; Risk level thresholds
(define-constant risk-low u1)
(define-constant risk-medium u2)
(define-constant risk-high u3)
(define-constant risk-critical u4)

;; Policy status constants
(define-constant status-pending u0)
(define-constant status-active u1)
(define-constant status-suspended u2)
(define-constant status-expired u3)

;; data maps and vars
;; Stores applicant health data and AI risk scores
(define-map applicants
    { applicant: principal }
    {
        age: uint,
        bmi: uint,
        pre-existing-conditions: uint,
        lifestyle-score: uint,
        ai-risk-score: uint,
        risk-level: uint,
        application-timestamp: uint
    }
)

;; Stores issued insurance policies
(define-map policies
    { policy-id: uint }
    {
        holder: principal,
        premium: uint,
        coverage-amount: uint,
        start-block: uint,
        end-block: uint,
        status: uint,
        claims-count: uint,
        total-claimed: uint
    }
)

;; Maps policy holders to their policy IDs
(define-map holder-policies
    { holder: principal }
    { policy-id: uint }
)

;; Stores claim information
(define-map claims
    { claim-id: uint }
    {
        policy-id: uint,
        claimant: principal,
        amount: uint,
        claim-type: uint,
        ai-fraud-score: uint,
        status: uint,
        submission-block: uint,
        resolution-block: uint
    }
)

;; AI model parameters for risk assessment
(define-map ai-model-weights
    { parameter: (string-ascii 32) }
    { weight: uint }
)

;; Contract state variables
(define-data-var policy-counter uint u0)
(define-data-var claim-counter uint u0)
(define-data-var total-premiums-collected uint u0)
(define-data-var total-claims-paid uint u0)
(define-data-var ai-model-version uint u1)

;; private functions
;; Calculate AI-driven risk score based on health metrics
(define-private (calculate-ai-risk-score (age uint) (bmi uint) (conditions uint) (lifestyle uint))
    (let
        (
            (age-weight (default-to u25 (get weight (map-get? ai-model-weights { parameter: "age-weight" }))))
            (bmi-weight (default-to u30 (get weight (map-get? ai-model-weights { parameter: "bmi-weight" }))))
            (condition-weight (default-to u35 (get weight (map-get? ai-model-weights { parameter: "condition-weight" }))))
            (lifestyle-weight (default-to u10 (get weight (map-get? ai-model-weights { parameter: "lifestyle-weight" }))))
            (age-score (/ (* age age-weight) u100))
            (bmi-score (/ (* bmi bmi-weight) u100))
            (condition-score (/ (* conditions condition-weight) u100))
            (lifestyle-score (/ (* lifestyle lifestyle-weight) u100))
        )
        (+ (+ age-score bmi-score) (+ condition-score lifestyle-score))
    )
)

;; Determine risk level from AI score
(define-private (get-risk-level (ai-score uint))
    (if (<= ai-score u30)
        risk-low
        (if (<= ai-score u60)
            risk-medium
            (if (<= ai-score u85)
                risk-high
                risk-critical
            )
        )
    )
)

;; Calculate premium based on risk level and coverage
(define-private (calculate-premium (risk-level uint) (coverage uint))
    (let
        (
            (base-rate (if (is-eq risk-level risk-low)
                u2
                (if (is-eq risk-level risk-medium)
                    u4
                    (if (is-eq risk-level risk-high)
                        u7
                        u12
                    )
                )
            ))
        )
        (/ (* coverage base-rate) u100)
    )
)

;; Validate health metrics
(define-private (validate-health-data (age uint) (bmi uint) (conditions uint) (lifestyle uint))
    (and
        (and (>= age u18) (<= age u100))
        (and (>= bmi u15) (<= bmi u50))
        (<= conditions u10)
        (<= lifestyle u100)
    )
)

;; public functions
;; Initialize AI model weights (owner only)
(define-public (initialize-ai-model)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set ai-model-weights { parameter: "age-weight" } { weight: u25 })
        (map-set ai-model-weights { parameter: "bmi-weight" } { weight: u30 })
        (map-set ai-model-weights { parameter: "condition-weight" } { weight: u35 })
        (map-set ai-model-weights { parameter: "lifestyle-weight" } { weight: u10 })
        (ok true)
    )
)

;; Submit insurance application with health data
(define-public (submit-application (age uint) (bmi uint) (pre-existing uint) (lifestyle uint))
    (let
        (
            (ai-score (calculate-ai-risk-score age bmi pre-existing lifestyle))
            (risk (get-risk-level ai-score))
        )
        (asserts! (validate-health-data age bmi pre-existing lifestyle) err-invalid-input)
        (asserts! (is-none (map-get? applicants { applicant: tx-sender })) err-already-exists)
        (map-set applicants
            { applicant: tx-sender }
            {
                age: age,
                bmi: bmi,
                pre-existing-conditions: pre-existing,
                lifestyle-score: lifestyle,
                ai-risk-score: ai-score,
                risk-level: risk,
                application-timestamp: block-height
            }
        )
        (ok { ai-risk-score: ai-score, risk-level: risk })
    )
)

;; Issue policy after application approval
(define-public (issue-policy (applicant principal) (coverage-amount uint) (duration-blocks uint))
    (let
        (
            (application (unwrap! (map-get? applicants { applicant: applicant }) err-not-found))
            (risk-level (get risk-level application))
            (premium (calculate-premium risk-level coverage-amount))
            (new-policy-id (+ (var-get policy-counter) u1))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-none (map-get? holder-policies { holder: applicant })) err-already-exists)
        (map-set policies
            { policy-id: new-policy-id }
            {
                holder: applicant,
                premium: premium,
                coverage-amount: coverage-amount,
                start-block: block-height,
                end-block: (+ block-height duration-blocks),
                status: status-active,
                claims-count: u0,
                total-claimed: u0
            }
        )
        (map-set holder-policies { holder: applicant } { policy-id: new-policy-id })
        (var-set policy-counter new-policy-id)
        (ok { policy-id: new-policy-id, premium: premium })
    )
)

;; Pay premium for active policy
(define-public (pay-premium (policy-id uint) (amount uint))
    (let
        (
            (policy (unwrap! (map-get? policies { policy-id: policy-id }) err-not-found))
            (required-premium (get premium policy))
        )
        (asserts! (is-eq tx-sender (get holder policy)) err-unauthorized)
        (asserts! (>= amount required-premium) err-insufficient-funds)
        (asserts! (is-eq (get status policy) status-active) err-policy-expired)
        (var-set total-premiums-collected (+ (var-get total-premiums-collected) amount))
        (ok true)
    )
)

;; Submit insurance claim with AI fraud detection
(define-public (submit-claim (policy-id uint) (claim-amount uint) (claim-type uint))
    (let
        (
            (policy (unwrap! (map-get? policies { policy-id: policy-id }) err-not-found))
            (new-claim-id (+ (var-get claim-counter) u1))
            (fraud-score (mod (+ claim-amount (* claim-type u7)) u100))
        )
        (asserts! (is-eq tx-sender (get holder policy)) err-unauthorized)
        (asserts! (is-eq (get status policy) status-active) err-policy-expired)
        (asserts! (<= claim-amount (get coverage-amount policy)) err-invalid-input)
        (asserts! (< block-height (get end-block policy)) err-policy-expired)
        (map-set claims
            { claim-id: new-claim-id }
            {
                policy-id: policy-id,
                claimant: tx-sender,
                amount: claim-amount,
                claim-type: claim-type,
                ai-fraud-score: fraud-score,
                status: status-pending,
                submission-block: block-height,
                resolution-block: u0
            }
        )
        (var-set claim-counter new-claim-id)
        (ok { claim-id: new-claim-id, fraud-score: fraud-score })
    )
)

;; Process claim with AI-assisted decision
(define-public (process-claim (claim-id uint) (approved bool))
    (let
        (
            (claim (unwrap! (map-get? claims { claim-id: claim-id }) err-not-found))
            (policy-id (get policy-id claim))
            (policy (unwrap! (map-get? policies { policy-id: policy-id }) err-not-found))
            (claim-amount (get amount claim))
            (fraud-score (get ai-fraud-score claim))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-eq (get status claim) status-pending) err-invalid-input)
        (if (and approved (< fraud-score u70))
            (begin
                (map-set claims
                    { claim-id: claim-id }
                    (merge claim { status: status-active, resolution-block: block-height })
                )
                (map-set policies
                    { policy-id: policy-id }
                    (merge policy {
                        claims-count: (+ (get claims-count policy) u1),
                        total-claimed: (+ (get total-claimed policy) claim-amount)
                    })
                )
                (var-set total-claims-paid (+ (var-get total-claims-paid) claim-amount))
                (ok true)
            )
            (begin
                (map-set claims
                    { claim-id: claim-id }
                    (merge claim { status: status-expired, resolution-block: block-height })
                )
                err-claim-rejected
            )
        )
    )
)

;; Update AI model weights for improved accuracy (owner only)
(define-public (update-ai-weights (param (string-ascii 32)) (new-weight uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= new-weight u100) err-invalid-input)
        (map-set ai-model-weights { parameter: param } { weight: new-weight })
        (var-set ai-model-version (+ (var-get ai-model-version) u1))
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-applicant-data (applicant principal))
    (map-get? applicants { applicant: applicant })
)

(define-read-only (get-policy-details (policy-id uint))
    (map-get? policies { policy-id: policy-id })
)

(define-read-only (get-claim-details (claim-id uint))
    (map-get? claims { claim-id: claim-id })
)

(define-read-only (get-contract-stats)
    (ok {
        total-policies: (var-get policy-counter),
        total-claims: (var-get claim-counter),
        premiums-collected: (var-get total-premiums-collected),
        claims-paid: (var-get total-claims-paid),
        ai-model-version: (var-get ai-model-version)
    })
)

;; Advanced AI-driven dynamic premium recalculation feature
;; This function analyzes policy performance and adjusts premiums based on claims history,
;; AI risk reassessment, and behavioral patterns to ensure fair pricing and sustainability
(define-public (recalculate-premium-with-ai-analysis 
    (policy-id uint) 
    (new-health-score uint) 
    (behavioral-improvement uint))
    (let
        (
            (policy (unwrap! (map-get? policies { policy-id: policy-id }) err-not-found))
            (holder (get holder policy))
            (applicant-data (unwrap! (map-get? applicants { applicant: holder }) err-not-found))
            (current-premium (get premium policy))
            (claims-count (get claims-count policy))
            (total-claimed (get total-claimed policy))
            (coverage (get coverage-amount policy))
            
            ;; AI-driven risk reassessment factors
            (claims-ratio (if (> coverage u0) (/ (* total-claimed u100) coverage) u0))
            (frequency-penalty (if (> claims-count u3) (* claims-count u5) u0))
            (health-improvement-bonus (if (> new-health-score u70) u10 u0))
            (behavioral-bonus (/ behavioral-improvement u10))
            
            ;; Calculate adjustment factor (can increase or decrease premium)
            (risk-adjustment (+ claims-ratio frequency-penalty))
            (improvement-bonus (+ health-improvement-bonus behavioral-bonus))
            (net-adjustment (if (> risk-adjustment improvement-bonus)
                (- risk-adjustment improvement-bonus)
                u0))
            
            ;; Apply adjustment with caps (max 50% increase, max 30% decrease)
            (adjustment-multiplier (if (> net-adjustment u50) u150 (+ u100 net-adjustment)))
            (discount-multiplier (if (> improvement-bonus risk-adjustment)
                (let ((discount (- improvement-bonus risk-adjustment)))
                    (if (> discount u30) u70 (- u100 discount)))
                u100))
            
            (final-multiplier (if (> adjustment-multiplier u100) adjustment-multiplier discount-multiplier))
            (new-premium (/ (* current-premium final-multiplier) u100))
            
            ;; Update AI risk score based on new data
            (updated-ai-score (calculate-ai-risk-score 
                (get age applicant-data)
                (get bmi applicant-data)
                (get pre-existing-conditions applicant-data)
                new-health-score))
            (new-risk-level (get-risk-level updated-ai-score))
        )
        ;; Validate authorization and policy status
        (asserts! (or (is-eq tx-sender contract-owner) (is-eq tx-sender holder)) err-unauthorized)
        (asserts! (is-eq (get status policy) status-active) err-policy-expired)
        (asserts! (<= new-health-score u100) err-invalid-input)
        (asserts! (<= behavioral-improvement u100) err-invalid-input)
        
        ;; Update policy with new premium
        (map-set policies
            { policy-id: policy-id }
            (merge policy { premium: new-premium })
        )
        
        ;; Update applicant data with new AI assessment
        (map-set applicants
            { applicant: holder }
            (merge applicant-data {
                lifestyle-score: new-health-score,
                ai-risk-score: updated-ai-score,
                risk-level: new-risk-level
            })
        )
        
        (ok {
            old-premium: current-premium,
            new-premium: new-premium,
            adjustment-percent: (if (> new-premium current-premium)
                (- final-multiplier u100)
                (- u100 final-multiplier)),
            updated-risk-level: new-risk-level,
            ai-risk-score: updated-ai-score
        })
    )
)


