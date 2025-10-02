;; pet-behavior-engine
;; Module that simulates pet reactions based on user interactions

;; Constants for pet states and limits
(define-constant MAX-HEALTH u100)
(define-constant MAX-HAPPINESS u100)
(define-constant MAX-ENERGY u100)
(define-constant MAX-HUNGER u100)
(define-constant DECAY-RATE u5)
(define-constant INTERACTION-BONUS u10)
(define-constant EVOLUTION-THRESHOLD u1000)

;; Error constants
(define-constant ERR-NOT-FOUND u404)
(define-constant ERR-UNAUTHORIZED u401)
(define-constant ERR-INVALID-INPUT u400)
(define-constant ERR-ALREADY-EXISTS u409)
(define-constant ERR-INSUFFICIENT-STATS u422)

;; Data variables for global pet counter
(define-data-var pet-counter uint u0)
(define-data-var contract-owner principal tx-sender)

;; Pet data structure
(define-map pets
  { pet-id: uint }
  {
    owner: principal,
    name: (string-ascii 32),
    pet-type: (string-ascii 16),
    health: uint,
    happiness: uint,
    energy: uint,
    hunger: uint,
    level: uint,
    experience: uint,
    birth-block: uint,
    last-interaction: uint,
    mood: (string-ascii 16),
    is-active: bool
  }
)

;; Pet interaction history
(define-map interaction-history
  { pet-id: uint, interaction-id: uint }
  {
    interaction-type: (string-ascii 16),
    block-height: uint,
    stat-changes: { health: int, happiness: int, energy: int, hunger: int },
    mood-change: (string-ascii 16)
  }
)

;; User pet ownership tracking
(define-map user-pets
  { owner: principal }
  { pet-ids: (list 10 uint), pet-count: uint }
)

;; Pet evolution milestones
(define-map evolution-milestones
  { pet-id: uint, milestone: uint }
  { achieved-block: uint, bonus-stats: { health: uint, happiness: uint } }
)

;; Public function to create a new pet
(define-public (create-pet (name (string-ascii 32)) (pet-type (string-ascii 16)))
  (let
    (
      (new-pet-id (+ (var-get pet-counter) u1))
      (current-block stacks-block-height)
    )
    (begin
      ;; Validate inputs
      (asserts! (> (len name) u0) (err ERR-INVALID-INPUT))
      (asserts! (> (len pet-type) u0) (err ERR-INVALID-INPUT))
      
      ;; Create the new pet
      (map-set pets
        { pet-id: new-pet-id }
        {
          owner: tx-sender,
          name: name,
          pet-type: pet-type,
          health: u80,
          happiness: u70,
          energy: u90,
          hunger: u60,
          level: u1,
          experience: u0,
          birth-block: current-block,
          last-interaction: current-block,
          mood: "happy",
          is-active: true
        }
      )
      
      ;; Update user pet ownership
      (match (map-get? user-pets { owner: tx-sender })
        existing-pets
          (map-set user-pets
            { owner: tx-sender }
            {
              pet-ids: (unwrap! (as-max-len? (append (get pet-ids existing-pets) new-pet-id) u10) (err ERR-INVALID-INPUT)),
              pet-count: (+ (get pet-count existing-pets) u1)
            }
          )
        (map-set user-pets
          { owner: tx-sender }
          { pet-ids: (list new-pet-id), pet-count: u1 }
        )
      )
      
      ;; Increment pet counter
      (var-set pet-counter new-pet-id)
      
      (ok new-pet-id)
    )
  )
)

;; Public function to feed a pet
(define-public (feed-pet (pet-id uint))
  (let
    (
      (pet-data (unwrap! (map-get? pets { pet-id: pet-id }) (err ERR-NOT-FOUND)))
    )
    (begin
      ;; Check ownership
      (asserts! (is-eq (get owner pet-data) tx-sender) (err ERR-UNAUTHORIZED))
      (asserts! (get is-active pet-data) (err ERR-INVALID-INPUT))
      
      ;; Apply natural decay first
      (let
        (
          (updated-pet (apply-natural-decay pet-data))
          (new-hunger (if (>= (get hunger updated-pet) u20) (- (get hunger updated-pet) u20) u0))
          (new-happiness (min MAX-HAPPINESS (+ (get happiness updated-pet) INTERACTION-BONUS)))
          (new-health (min MAX-HEALTH (+ (get health updated-pet) u5)))
          (experience-gain u10)
        )
        ;; Update pet stats
        (map-set pets
          { pet-id: pet-id }
          (merge updated-pet {
            hunger: new-hunger,
            happiness: new-happiness,
            health: new-health,
            experience: (+ (get experience updated-pet) experience-gain),
            last-interaction: stacks-block-height,
            mood: (calculate-mood new-health new-happiness (get energy updated-pet) new-hunger)
          })
        )
        
        ;; Record interaction
        (record-interaction pet-id "feed" { health: 5, happiness: (to-int INTERACTION-BONUS), energy: 0, hunger: -20 })
        
        (ok true)
      )
    )
  )
)

;; Public function to play with a pet
(define-public (play-with-pet (pet-id uint))
  (let
    (
      (pet-data (unwrap! (map-get? pets { pet-id: pet-id }) (err ERR-NOT-FOUND)))
    )
    (begin
      ;; Check ownership and pet activity
      (asserts! (is-eq (get owner pet-data) tx-sender) (err ERR-UNAUTHORIZED))
      (asserts! (get is-active pet-data) (err ERR-INVALID-INPUT))
      (asserts! (>= (get energy pet-data) u20) (err ERR-INSUFFICIENT-STATS))
      
      ;; Apply natural decay first
      (let
        (
          (updated-pet (apply-natural-decay pet-data))
          (new-energy (- (get energy updated-pet) u15))
          (new-happiness (min MAX-HAPPINESS (+ (get happiness updated-pet) u15)))
          (new-hunger (min MAX-HUNGER (+ (get hunger updated-pet) u10)))
          (experience-gain u15)
        )
        ;; Update pet stats
        (map-set pets
          { pet-id: pet-id }
          (merge updated-pet {
            energy: new-energy,
            happiness: new-happiness,
            hunger: new-hunger,
            experience: (+ (get experience updated-pet) experience-gain),
            last-interaction: stacks-block-height,
            mood: (calculate-mood (get health updated-pet) new-happiness new-energy new-hunger)
          })
        )
        
        ;; Record interaction
        (record-interaction pet-id "play" { health: 0, happiness: 15, energy: -15, hunger: 10 })
        
        (ok true)
      )
    )
  )
)

;; Public function to let pet rest
(define-public (rest-pet (pet-id uint))
  (let
    (
      (pet-data (unwrap! (map-get? pets { pet-id: pet-id }) (err ERR-NOT-FOUND)))
    )
    (begin
      ;; Check ownership
      (asserts! (is-eq (get owner pet-data) tx-sender) (err ERR-UNAUTHORIZED))
      (asserts! (get is-active pet-data) (err ERR-INVALID-INPUT))
      
      ;; Apply natural decay first
      (let
        (
          (updated-pet (apply-natural-decay pet-data))
          (new-energy (min MAX-ENERGY (+ (get energy updated-pet) u25)))
          (new-health (min MAX-HEALTH (+ (get health updated-pet) u5)))
          (experience-gain u5)
        )
        ;; Update pet stats
        (map-set pets
          { pet-id: pet-id }
          (merge updated-pet {
            energy: new-energy,
            health: new-health,
            experience: (+ (get experience updated-pet) experience-gain),
            last-interaction: stacks-block-height,
            mood: (calculate-mood new-health (get happiness updated-pet) new-energy (get hunger updated-pet))
          })
        )
        
        ;; Record interaction
        (record-interaction pet-id "rest" { health: 5, happiness: 0, energy: 25, hunger: 0 })
        
        (ok true)
      )
    )
  )
)

;; Public function to train a pet
(define-public (train-pet (pet-id uint))
  (let
    (
      (pet-data (unwrap! (map-get? pets { pet-id: pet-id }) (err ERR-NOT-FOUND)))
    )
    (begin
      ;; Check ownership and requirements
      (asserts! (is-eq (get owner pet-data) tx-sender) (err ERR-UNAUTHORIZED))
      (asserts! (get is-active pet-data) (err ERR-INVALID-INPUT))
      (asserts! (>= (get energy pet-data) u30) (err ERR-INSUFFICIENT-STATS))
      (asserts! (>= (get happiness pet-data) u20) (err ERR-INSUFFICIENT-STATS))
      
      ;; Apply natural decay first
      (let
        (
          (updated-pet (apply-natural-decay pet-data))
          (new-energy (- (get energy updated-pet) u25))
          (new-hunger (min MAX-HUNGER (+ (get hunger updated-pet) u15)))
          (new-health (min MAX-HEALTH (+ (get health updated-pet) u10)))
          (experience-gain u20)
          (new-experience (+ (get experience updated-pet) experience-gain))
          (new-level (calculate-level new-experience))
        )
        ;; Update pet stats
        (map-set pets
          { pet-id: pet-id }
          (merge updated-pet {
            energy: new-energy,
            hunger: new-hunger,
            health: new-health,
            experience: new-experience,
            level: new-level,
            last-interaction: stacks-block-height,
            mood: (calculate-mood new-health (get happiness updated-pet) new-energy new-hunger)
          })
        )
        
        ;; Record interaction
        (record-interaction pet-id "train" { health: 10, happiness: 0, energy: -25, hunger: 15 })
        
        ;; Check for evolution milestone
        (check-evolution-milestone pet-id new-level)
        
        (ok true)
      )
    )
  )
)

;; Read-only function to get pet details
(define-read-only (get-pet-details (pet-id uint))
  (match (map-get? pets { pet-id: pet-id })
    pet-data (ok pet-data)
    (err ERR-NOT-FOUND)
  )
)

;; Read-only function to get user's pets
(define-read-only (get-user-pets (owner principal))
  (match (map-get? user-pets { owner: owner })
    user-data (ok user-data)
    (err ERR-NOT-FOUND)
  )
)

;; Read-only function to check pet's current status with decay applied
(define-read-only (get-pet-current-status (pet-id uint))
  (match (map-get? pets { pet-id: pet-id })
    pet-data 
      (let
        (
          (updated-pet (apply-natural-decay pet-data))
        )
        (ok {
          pet-id: pet-id,
          health: (get health updated-pet),
          happiness: (get happiness updated-pet),
          energy: (get energy updated-pet),
          hunger: (get hunger updated-pet),
          level: (get level updated-pet),
          mood: (get mood updated-pet),
          needs-attention: (or (< (get health updated-pet) u20) 
                              (< (get happiness updated-pet) u20) 
                              (> (get hunger updated-pet) u80))
        })
      )
    (err ERR-NOT-FOUND)
  )
)

;; Read-only function to get interaction history
(define-read-only (get-interaction-history (pet-id uint) (interaction-id uint))
  (map-get? interaction-history { pet-id: pet-id, interaction-id: interaction-id })
)

;; Private helper functions for min/max
(define-private (min (a uint) (b uint))
  (if (<= a b) a b)
)

(define-private (max (a uint) (b uint))
  (if (>= a b) a b)
)

;; Private function to apply natural decay over time
(define-private (apply-natural-decay (pet-data { owner: principal, name: (string-ascii 32), pet-type: (string-ascii 16), health: uint, happiness: uint, energy: uint, hunger: uint, level: uint, experience: uint, birth-block: uint, last-interaction: uint, mood: (string-ascii 16), is-active: bool }))
  (let
    (
      (blocks-passed (- stacks-block-height (get last-interaction pet-data)))
      (decay-amount (* blocks-passed DECAY-RATE))
      (new-happiness (if (>= (get happiness pet-data) decay-amount) (- (get happiness pet-data) decay-amount) u0))
      (new-energy (if (>= (get energy pet-data) decay-amount) (- (get energy pet-data) decay-amount) u0))
      (new-hunger (min MAX-HUNGER (+ (get hunger pet-data) decay-amount)))
      (new-health (if (and (< new-happiness u20) (> new-hunger u80)) 
                      (if (>= (get health pet-data) u2) (- (get health pet-data) u2) u0)
                      (get health pet-data)))
    )
    (merge pet-data {
      happiness: new-happiness,
      energy: new-energy,
      hunger: new-hunger,
      health: new-health,
      mood: (calculate-mood new-health new-happiness new-energy new-hunger)
    })
  )
)

;; Private function to calculate pet mood based on stats
(define-private (calculate-mood (health uint) (happiness uint) (energy uint) (hunger uint))
  (if (and (>= health u80) (>= happiness u70) (>= energy u60) (<= hunger u30))
    "ecstatic"
    (if (and (>= health u60) (>= happiness u50) (>= energy u40) (<= hunger u50))
      "happy"
      (if (and (>= health u40) (>= happiness u30) (>= energy u20) (<= hunger u70))
        "content"
        (if (and (>= health u20) (>= happiness u20) (>= energy u10) (<= hunger u80))
          "tired"
          "sick"
        )
      )
    )
  )
)

;; Private function to calculate level based on experience
(define-private (calculate-level (experience uint))
  (+ u1 (/ experience u100))
)

;; Private function to record interactions
(define-private (record-interaction (pet-id uint) (interaction-type (string-ascii 16)) (stat-changes { health: int, happiness: int, energy: int, hunger: int }))
  (let
    (
      (interaction-id (+ (* pet-id u1000) (mod stacks-block-height u1000)))
    )
    (map-set interaction-history
      { pet-id: pet-id, interaction-id: interaction-id }
      {
        interaction-type: interaction-type,
        block-height: stacks-block-height,
        stat-changes: stat-changes,
        mood-change: (match (map-get? pets { pet-id: pet-id })
                        pet-data (get mood pet-data)
                        "unknown"
                      )
      }
    )
  )
)

;; Private function to check evolution milestones
(define-private (check-evolution-milestone (pet-id uint) (level uint))
  (if (and (is-eq (mod level u5) u0) (> level u1))
    (map-set evolution-milestones
      { pet-id: pet-id, milestone: level }
      {
        achieved-block: stacks-block-height,
        bonus-stats: { health: u10, happiness: u10 }
      }
    )
    true
  )
)

