;; Donation Tracker Smart Contract
;; Track donations from donor to beneficiary with transparent impact reporting
;; This contract enables complete transparency in charitable giving with immutable tracking

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-CHARITY-NOT-FOUND (err u101))
(define-constant ERR-CHARITY-NOT-VERIFIED (err u102))
(define-constant ERR-PROJECT-NOT-FOUND (err u103))
(define-constant ERR-DONATION-NOT-FOUND (err u104))
(define-constant ERR-INSUFFICIENT-FUNDS (err u105))
(define-constant ERR-PROJECT-NOT-ACTIVE (err u106))
(define-constant ERR-MILESTONE-NOT-FOUND (err u107))
(define-constant ERR-INVALID-AMOUNT (err u108))
(define-constant ERR-PROJECT-COMPLETED (err u109))
(define-constant ERR-MILESTONE-ALREADY-COMPLETED (err u110))

;; Charity Status
(define-constant STATUS-PENDING u1)
(define-constant STATUS-VERIFIED u2)
(define-constant STATUS-SUSPENDED u3)
(define-constant STATUS-REVOKED u4)

;; Project Status  
(define-constant PROJECT-STATUS-ACTIVE u1)
(define-constant PROJECT-STATUS-COMPLETED u2)
(define-constant PROJECT-STATUS-CANCELLED u3)
(define-constant PROJECT-STATUS-SUSPENDED u4)

;; Milestone Status
(define-constant MILESTONE-PENDING u1)
(define-constant MILESTONE-IN-PROGRESS u2)
(define-constant MILESTONE-COMPLETED u3)
(define-constant MILESTONE-VERIFIED u4)

;; Impact Categories
(define-constant CATEGORY-EDUCATION u1)
(define-constant CATEGORY-HEALTHCARE u2)
(define-constant CATEGORY-ENVIRONMENT u3)
(define-constant CATEGORY-POVERTY u4)
(define-constant CATEGORY-DISASTER-RELIEF u5)
(define-constant CATEGORY-OTHER u6)

;; Platform Configuration
(define-constant PLATFORM-FEE-RATE u100) ;; 1% platform fee (100/10000)
(define-constant MIN-DONATION-AMOUNT u1000000) ;; 1 STX minimum
(define-constant MAX-ADMIN-COUNT u5)

;; Data Variables
(define-data-var charity-counter uint u0)
(define-data-var project-counter uint u0)
(define-data-var donation-counter uint u0)
(define-data-var milestone-counter uint u0)
(define-data-var total-donations uint u0)
(define-data-var total-platform-fees uint u0)

;; Data Maps

;; Charities
(define-map charities
    uint ;; charity-id
    {
        name: (string-ascii 128),
        description: (string-ascii 512),
        website: (string-ascii 64),
        contact-email: (string-ascii 64),
        registration-number: (string-ascii 32),
        country: (string-ascii 32),
        admin: principal,
        status: uint,
        verification-date: uint,
        total-raised: uint,
        project-count: uint,
        impact-score: uint ;; 0-100 rating
    }
)

;; Charity administrators
(define-map charity-admins
    {charity-id: uint, admin: principal}
    {
        role: (string-ascii 32), ;; "admin", "manager", "reporter"
        added-by: principal,
        added-date: uint,
        is-active: bool
    }
)

;; Projects
(define-map projects
    uint ;; project-id
    {
        charity-id: uint,
        title: (string-ascii 128),
        description: (string-ascii 512),
        category: uint,
        target-amount: uint,
        raised-amount: uint,
        start-date: uint,
        end-date: uint,
        status: uint,
        beneficiary-count: uint,
        milestone-count: uint,
        completed-milestones: uint,
        impact-description: (string-ascii 256),
        location: (string-ascii 64)
    }
)

;; Donations
(define-map donations
    uint ;; donation-id
    {
        donor: principal,
        charity-id: uint,
        project-id: uint,
        amount: uint,
        platform-fee: uint,
        net-amount: uint,
        donation-date: uint,
        message: (optional (string-ascii 256)),
        is-anonymous: bool,
        tax-receipt-requested: bool
    }
)

;; Project milestones
(define-map milestones
    uint ;; milestone-id
    {
        project-id: uint,
        title: (string-ascii 128),
        description: (string-ascii 256),
        target-amount: uint,
        raised-amount: uint,
        deadline: uint,
        status: uint,
        completion-date: (optional uint),
        impact-metrics: (string-ascii 256),
        evidence-hash: (optional (buff 32))
    }
)

;; Impact reports
(define-map impact-reports
    {project-id: uint, report-id: uint}
    {
        title: (string-ascii 128),
        description: (string-ascii 512),
        beneficiaries-reached: uint,
        funds-utilized: uint,
        outcomes-achieved: (string-ascii 256),
        evidence-hash: (buff 32),
        reporter: principal,
        report-date: uint,
        verified: bool
    }
)

;; Donor profiles
(define-map donor-profiles
    principal
    {
        total-donated: uint,
        donation-count: uint,
        favorite-categories: (list 3 uint),
        preferred-anonymous: bool,
        registration-date: uint,
        impact-score: uint
    }
)

;; Project donations tracking
(define-map project-donations
    uint ;; project-id
    (list 100 uint) ;; list of donation-ids
)

;; Charity verification documents
(define-map verification-documents
    uint ;; charity-id
    {
        registration-doc-hash: (buff 32),
        tax-exempt-status-hash: (optional (buff 32)),
        financial-report-hash: (optional (buff 32)),
        verifier: principal,
        verification-notes: (string-ascii 256)
    }
)

(define-data-var report-counter uint u0)

;; Public Functions

;; Register new charity
(define-public (register-charity
    (name (string-ascii 128))
    (description (string-ascii 512))
    (website (string-ascii 64))
    (contact-email (string-ascii 64))
    (registration-number (string-ascii 32))
    (country (string-ascii 32))
    (registration-doc-hash (buff 32))
    )
    (let
        (
            (charity-id (+ (var-get charity-counter) u1))
        )
        ;; Create charity record
        (map-set charities charity-id {
            name: name,
            description: description,
            website: website,
            contact-email: contact-email,
            registration-number: registration-number,
            country: country,
            admin: tx-sender,
            status: STATUS-PENDING,
            verification-date: u0,
            total-raised: u0,
            project-count: u0,
            impact-score: u0
        })
        
        ;; Add primary admin
        (map-set charity-admins {charity-id: charity-id, admin: tx-sender} {
            role: "admin",
            added-by: tx-sender,
            added-date: stacks-block-height,
            is-active: true
        })
        
        ;; Store verification documents
        (map-set verification-documents charity-id {
            registration-doc-hash: registration-doc-hash,
            tax-exempt-status-hash: none,
            financial-report-hash: none,
            verifier: tx-sender,
            verification-notes: "Pending verification"
        })
        
        ;; Update counter
        (var-set charity-counter charity-id)
        
        (ok charity-id)
    )
)

;; Verify charity (admin only)
(define-public (verify-charity (charity-id uint) (notes (string-ascii 256)))
    (let
        (
            (charity (unwrap! (map-get? charities charity-id) ERR-CHARITY-NOT-FOUND))
        )
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        
        ;; Update charity status
        (map-set charities charity-id
            (merge charity {
                status: STATUS-VERIFIED,
                verification-date: stacks-block-height
            })
        )
        
        ;; Update verification notes
        (let
            (
                (docs (unwrap-panic (map-get? verification-documents charity-id)))
            )
            (map-set verification-documents charity-id
                (merge docs {
                    verifier: tx-sender,
                    verification-notes: notes
                })
            )
        )
        
        (ok true)
    )
)

;; Create project
(define-public (create-project
    (charity-id uint)
    (title (string-ascii 128))
    (description (string-ascii 512))
    (category uint)
    (target-amount uint)
    (end-date uint)
    (beneficiary-count uint)
    (location (string-ascii 64))
    )
    (let
        (
            (charity (unwrap! (map-get? charities charity-id) ERR-CHARITY-NOT-FOUND))
            (project-id (+ (var-get project-counter) u1))
            (admin-check (map-get? charity-admins {charity-id: charity-id, admin: tx-sender}))
        )
        ;; Validate permissions
        (asserts! (is-some admin-check) ERR-NOT-AUTHORIZED)
        (asserts! (get is-active (unwrap-panic admin-check)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status charity) STATUS-VERIFIED) ERR-CHARITY-NOT-VERIFIED)
        (asserts! (and (>= category u1) (<= category u6)) ERR-INVALID-AMOUNT)
        (asserts! (> target-amount u0) ERR-INVALID-AMOUNT)
        
        ;; Create project
        (map-set projects project-id {
            charity-id: charity-id,
            title: title,
            description: description,
            category: category,
            target-amount: target-amount,
            raised-amount: u0,
            start-date: stacks-block-height,
            end-date: end-date,
            status: PROJECT-STATUS-ACTIVE,
            beneficiary-count: beneficiary-count,
            milestone-count: u0,
            completed-milestones: u0,
            impact-description: "",
            location: location
        })
        
        ;; Initialize project donations list
        (map-set project-donations project-id (list))
        
        ;; Update charity project count
        (map-set charities charity-id
            (merge charity {
                project-count: (+ (get project-count charity) u1)
            })
        )
        
        ;; Update counter
        (var-set project-counter project-id)
        
        (ok project-id)
    )
)

;; Make donation
(define-public (make-donation
    (charity-id uint)
    (project-id uint)
    (amount uint)
    (message (optional (string-ascii 256)))
    (is-anonymous bool)
    (tax-receipt-requested bool)
    )
    (let
        (
            (charity (unwrap! (map-get? charities charity-id) ERR-CHARITY-NOT-FOUND))
            (project (unwrap! (map-get? projects project-id) ERR-PROJECT-NOT-FOUND))
            (donation-id (+ (var-get donation-counter) u1))
            (platform-fee (/ (* amount PLATFORM-FEE-RATE) u10000))
            (net-amount (- amount platform-fee))
        )
        ;; Validate donation
        (asserts! (>= amount MIN-DONATION-AMOUNT) ERR-INVALID-AMOUNT)
        (asserts! (is-eq (get status charity) STATUS-VERIFIED) ERR-CHARITY-NOT-VERIFIED)
        (asserts! (is-eq (get status project) PROJECT-STATUS-ACTIVE) ERR-PROJECT-NOT-ACTIVE)
        (asserts! (is-eq (get charity-id project) charity-id) ERR-PROJECT-NOT-FOUND)
        
        ;; Transfer funds to contract (charity gets it later)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        ;; Create donation record
        (map-set donations donation-id {
            donor: tx-sender,
            charity-id: charity-id,
            project-id: project-id,
            amount: amount,
            platform-fee: platform-fee,
            net-amount: net-amount,
            donation-date: stacks-block-height,
            message: message,
            is-anonymous: is-anonymous,
            tax-receipt-requested: tax-receipt-requested
        })
        
        ;; Update project raised amount
        (map-set projects project-id
            (merge project {
                raised-amount: (+ (get raised-amount project) net-amount)
            })
        )
        
        ;; Update charity total raised
        (map-set charities charity-id
            (merge charity {
                total-raised: (+ (get total-raised charity) net-amount)
            })
        )
        
        ;; Update project donations list
        (let
            (
                (existing-donations (default-to (list) (map-get? project-donations project-id)))
            )
            (map-set project-donations project-id
                (unwrap! (as-max-len? (append existing-donations donation-id) u100) ERR-INVALID-AMOUNT)
            )
        )
        
        ;; Update donor profile
        (let
            (
                (donor-profile (default-to {
                    total-donated: u0,
                    donation-count: u0,
                    favorite-categories: (list),
                    preferred-anonymous: false,
                    registration-date: stacks-block-height,
                    impact-score: u0
                } (map-get? donor-profiles tx-sender)))
            )
            (map-set donor-profiles tx-sender
                (merge donor-profile {
                    total-donated: (+ (get total-donated donor-profile) amount),
                    donation-count: (+ (get donation-count donor-profile) u1)
                })
            )
        )
        
        ;; Transfer net amount to charity admin
        (try! (as-contract (stx-transfer? net-amount tx-sender (get admin charity))))
        
        ;; Update global counters
        (var-set donation-counter donation-id)
        (var-set total-donations (+ (var-get total-donations) amount))
        (var-set total-platform-fees (+ (var-get total-platform-fees) platform-fee))
        
        (ok donation-id)
    )
)

;; Create milestone
(define-public (create-milestone
    (project-id uint)
    (title (string-ascii 128))
    (description (string-ascii 256))
    (target-amount uint)
    (deadline uint)
    (impact-metrics (string-ascii 256))
    )
    (let
        (
            (project (unwrap! (map-get? projects project-id) ERR-PROJECT-NOT-FOUND))
            (milestone-id (+ (var-get milestone-counter) u1))
            (admin-check (map-get? charity-admins {charity-id: (get charity-id project), admin: tx-sender}))
        )
        ;; Validate permissions
        (asserts! (is-some admin-check) ERR-NOT-AUTHORIZED)
        (asserts! (get is-active (unwrap-panic admin-check)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status project) PROJECT-STATUS-ACTIVE) ERR-PROJECT-NOT-ACTIVE)
        
        ;; Create milestone
        (map-set milestones milestone-id {
            project-id: project-id,
            title: title,
            description: description,
            target-amount: target-amount,
            raised-amount: u0,
            deadline: deadline,
            status: MILESTONE-PENDING,
            completion-date: none,
            impact-metrics: impact-metrics,
            evidence-hash: none
        })
        
        ;; Update project milestone count
        (map-set projects project-id
            (merge project {
                milestone-count: (+ (get milestone-count project) u1)
            })
        )
        
        ;; Update counter
        (var-set milestone-counter milestone-id)
        
        (ok milestone-id)
    )
)

;; Complete milestone
(define-public (complete-milestone
    (milestone-id uint)
    (evidence-hash (buff 32))
    (impact-description (string-ascii 256))
    )
    (let
        (
            (milestone (unwrap! (map-get? milestones milestone-id) ERR-MILESTONE-NOT-FOUND))
            (project (unwrap! (map-get? projects (get project-id milestone)) ERR-PROJECT-NOT-FOUND))
            (admin-check (map-get? charity-admins {charity-id: (get charity-id project), admin: tx-sender}))
        )
        ;; Validate permissions
        (asserts! (is-some admin-check) ERR-NOT-AUTHORIZED)
        (asserts! (get is-active (unwrap-panic admin-check)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status milestone) MILESTONE-PENDING) ERR-MILESTONE-ALREADY-COMPLETED)
        
        ;; Update milestone
        (map-set milestones milestone-id
            (merge milestone {
                status: MILESTONE-COMPLETED,
                completion-date: (some stacks-block-height),
                evidence-hash: (some evidence-hash)
            })
        )
        
        ;; Update project completed milestones
        (map-set projects (get project-id milestone)
            (merge project {
                completed-milestones: (+ (get completed-milestones project) u1),
                impact-description: impact-description
            })
        )
        
        (ok true)
    )
)

;; Submit impact report
(define-public (submit-impact-report
    (project-id uint)
    (title (string-ascii 128))
    (description (string-ascii 512))
    (beneficiaries-reached uint)
    (funds-utilized uint)
    (outcomes-achieved (string-ascii 256))
    (evidence-hash (buff 32))
    )
    (let
        (
            (project (unwrap! (map-get? projects project-id) ERR-PROJECT-NOT-FOUND))
            (report-id (+ (var-get report-counter) u1))
            (admin-check (map-get? charity-admins {charity-id: (get charity-id project), admin: tx-sender}))
        )
        ;; Validate permissions
        (asserts! (is-some admin-check) ERR-NOT-AUTHORIZED)
        (asserts! (get is-active (unwrap-panic admin-check)) ERR-NOT-AUTHORIZED)
        
        ;; Create impact report
        (map-set impact-reports {project-id: project-id, report-id: report-id} {
            title: title,
            description: description,
            beneficiaries-reached: beneficiaries-reached,
            funds-utilized: funds-utilized,
            outcomes-achieved: outcomes-achieved,
            evidence-hash: evidence-hash,
            reporter: tx-sender,
            report-date: stacks-block-height,
            verified: false
        })
        
        ;; Update counter
        (var-set report-counter report-id)
        
        (ok report-id)
    )
)

;; Withdraw platform fees (admin only)
(define-public (withdraw-platform-fees (amount uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (<= amount (var-get total-platform-fees)) ERR-INSUFFICIENT-FUNDS)
        
        (try! (as-contract (stx-transfer? amount tx-sender CONTRACT-OWNER)))
        (var-set total-platform-fees (- (var-get total-platform-fees) amount))
        
        (ok true)
    )
)

;; Read-Only Functions

;; Get charity details
(define-read-only (get-charity (charity-id uint))
    (map-get? charities charity-id)
)

;; Get project details
(define-read-only (get-project (project-id uint))
    (map-get? projects project-id)
)

;; Get donation details
(define-read-only (get-donation (donation-id uint))
    (map-get? donations donation-id)
)

;; Get milestone details
(define-read-only (get-milestone (milestone-id uint))
    (map-get? milestones milestone-id)
)

;; Get impact report
(define-read-only (get-impact-report (project-id uint) (report-id uint))
    (map-get? impact-reports {project-id: project-id, report-id: report-id})
)

;; Get donor profile
(define-read-only (get-donor-profile (donor principal))
    (map-get? donor-profiles donor)
)

;; Get project donations
(define-read-only (get-project-donations (project-id uint))
    (map-get? project-donations project-id)
)

;; Get platform statistics
(define-read-only (get-platform-stats)
    {
        total-charities: (var-get charity-counter),
        total-projects: (var-get project-counter),
        total-donations-amount: (var-get total-donations),
        total-donations-count: (var-get donation-counter),
        total-milestones: (var-get milestone-counter),
        platform-fees-collected: (var-get total-platform-fees)
    }
)

;; Get category name
(define-read-only (get-category-name (category uint))
    (if (is-eq category CATEGORY-EDUCATION) "Education"
    (if (is-eq category CATEGORY-HEALTHCARE) "Healthcare"
    (if (is-eq category CATEGORY-ENVIRONMENT) "Environment"
    (if (is-eq category CATEGORY-POVERTY) "Poverty Alleviation"
    (if (is-eq category CATEGORY-DISASTER-RELIEF) "Disaster Relief"
    "Other"
    )))))
)

;; Check if charity is verified
(define-read-only (is-charity-verified (charity-id uint))
    (match (map-get? charities charity-id)
        charity (is-eq (get status charity) STATUS-VERIFIED)
        false
    )
)

