;; reward-system
;; Module that gives rewards for healthy habits like walking or exercising

;; Token definition for Pet Care Tokens (PCT)
(define-fungible-token pet-care-tokens)

;; Constants for reward calculations
(define-constant DAILY-REWARD u100)
(define-constant INTERACTION-REWARD u25)
(define-constant STREAK-MULTIPLIER u2)
(define-constant MAX-DAILY-CLAIMS u3)
(define-constant ACHIEVEMENT-REWARD u500)
(define-constant MILESTONE-BONUS u1000)

;; Error constants
(define-constant ERR-NOT-FOUND u404)
(define-constant ERR-UNAUTHORIZED u401)
(define-constant ERR-INVALID-INPUT u400)
(define-constant ERR-ALREADY-CLAIMED u409)
(define-constant ERR-INSUFFICIENT-BALANCE u422)
(define-constant ERR-MAX-CLAIMS-REACHED u429)
(define-constant ERR-STREAK-BROKEN u430)

;; Data variables for contract management
(define-data-var contract-owner principal tx-sender)
(define-data-var total-tokens-minted uint u0)
(define-data-var reward-pool-balance uint u10000000) ;; 10M initial pool
(define-data-var daily-reward-rate uint DAILY-REWARD)

;; User reward tracking
(define-map user-rewards
  { user: principal }
  {
    total-earned: uint,
    daily-streak: uint,
    longest-streak: uint,
    last-claim-day: uint,
    daily-claims-count: uint,
    achievements-unlocked: uint,
    lifetime-interactions: uint,
    bonus-multiplier: uint
  }
)

;; Daily claim tracking
(define-map daily-claims
  { user: principal, day: uint }
  {
    claims-made: uint,
    total-earned: uint,
    interactions-count: uint,
    streak-at-claim: uint
  }
)

;; Achievement system
(define-map achievements
  { achievement-id: uint }
  {
    name: (string-ascii 32),
    description: (string-ascii 64),
    reward-amount: uint,
    requirement-type: (string-ascii 16),
    requirement-value: uint,
    is-active: bool
  }
)

;; User achievements tracking
(define-map user-achievements
  { user: principal, achievement-id: uint }
  {
    unlocked-block: uint,
    reward-claimed: bool
  }
)

;; Leaderboard for competitions
(define-map leaderboard-entries
  { period: uint, rank: uint }
  {
    user: principal,
    score: uint,
    reward-earned: uint
  }
)

;; Reward distribution history
(define-map reward-history
  { user: principal, transaction-id: uint }
  {
    reward-type: (string-ascii 16),
    amount: uint,
    block-height: uint,
    reason: (string-ascii 32)
  }
)

;; Initialize default achievements
(map-set achievements { achievement-id: u1 } {
  name: "First Pet",
  description: "Create your first virtual pet",
  reward-amount: u200,
  requirement-type: "pets",
  requirement-value: u1,
  is-active: true
})

(map-set achievements { achievement-id: u2 } {
  name: "Caretaker",
  description: "Complete 10 pet interactions",
  reward-amount: u300,
  requirement-type: "interactions",
  requirement-value: u10,
  is-active: true
})

(map-set achievements { achievement-id: u3 } {
  name: "Dedication",
  description: "Maintain a 7-day streak",
  reward-amount: u750,
  requirement-type: "streak",
  requirement-value: u7,
  is-active: true
})

(map-set achievements { achievement-id: u4 } {
  name: "Pet Master",
  description: "Complete 100 pet interactions",
  reward-amount: u1500,
  requirement-type: "interactions",
  requirement-value: u100,
  is-active: true
})

;; Public function to claim daily rewards
(define-public (claim-daily-reward)
  (let
    (
      (current-day (/ stacks-block-height u144)) ;; Assuming 144 blocks per day
      (user-data (default-to 
        {
          total-earned: u0,
          daily-streak: u0,
          longest-streak: u0,
          last-claim-day: u0,
          daily-claims-count: u0,
          achievements-unlocked: u0,
          lifetime-interactions: u0,
          bonus-multiplier: u1
        }
        (map-get? user-rewards { user: tx-sender })
      ))
      (daily-claim-data (default-to
        { claims-made: u0, total-earned: u0, interactions-count: u0, streak-at-claim: u0 }
        (map-get? daily-claims { user: tx-sender, day: current-day })
      ))
    )
    (begin
      ;; Check if user can claim (max claims per day)
      (asserts! (< (get claims-made daily-claim-data) MAX-DAILY-CLAIMS) (err ERR-MAX-CLAIMS-REACHED))
      
      ;; Calculate reward amount with streak multiplier
      (let
        (
          (streak-bonus (calculate-streak-bonus (get daily-streak user-data)))
          (base-reward (var-get daily-reward-rate))
          (multiplier (get bonus-multiplier user-data))
          (total-reward (* (* base-reward multiplier) streak-bonus))
          (new-streak (calculate-new-streak user-data current-day))
        )
        
        ;; Mint and transfer tokens
        (try! (ft-mint? pet-care-tokens total-reward tx-sender))
        
        ;; Update user rewards data
        (map-set user-rewards
          { user: tx-sender }
          (merge user-data {
            total-earned: (+ (get total-earned user-data) total-reward),
            daily-streak: new-streak,
            longest-streak: (max (get longest-streak user-data) new-streak),
            last-claim-day: current-day
          })
        )
        
        ;; Update daily claims
        (map-set daily-claims
          { user: tx-sender, day: current-day }
          {
            claims-made: (+ (get claims-made daily-claim-data) u1),
            total-earned: (+ (get total-earned daily-claim-data) total-reward),
            interactions-count: (get interactions-count daily-claim-data),
            streak-at-claim: new-streak
          }
        )
        
        ;; Record reward transaction
        (record-reward-transaction "daily" total-reward "Daily care reward")
        
        ;; Check for streak achievements
        (check-streak-achievements new-streak)
        
        ;; Update contract stats
        (var-set total-tokens-minted (+ (var-get total-tokens-minted) total-reward))
        
        (ok total-reward)
      )
    )
  )
)

;; Public function to claim interaction rewards
(define-public (claim-interaction-reward (interaction-type (string-ascii 16)))
  (let
    (
      (user-data (default-to 
        {
          total-earned: u0,
          daily-streak: u0,
          longest-streak: u0,
          last-claim-day: u0,
          daily-claims-count: u0,
          achievements-unlocked: u0,
          lifetime-interactions: u0,
          bonus-multiplier: u1
        }
        (map-get? user-rewards { user: tx-sender })
      ))
      (reward-amount (calculate-interaction-reward interaction-type (get bonus-multiplier user-data)))
    )
    (begin
      ;; Mint and transfer tokens
      (try! (ft-mint? pet-care-tokens reward-amount tx-sender))
      
      ;; Update user data
      (map-set user-rewards
        { user: tx-sender }
        (merge user-data {
          total-earned: (+ (get total-earned user-data) reward-amount),
          lifetime-interactions: (+ (get lifetime-interactions user-data) u1)
        })
      )
      
      ;; Record transaction
      (record-reward-transaction "interaction" reward-amount interaction-type)
      
      ;; Check for interaction-based achievements
      (check-interaction-achievements (+ (get lifetime-interactions user-data) u1))
      
      ;; Update contract stats
      (var-set total-tokens-minted (+ (var-get total-tokens-minted) reward-amount))
      
      (ok reward-amount)
    )
  )
)

;; Public function to claim achievement rewards
(define-public (claim-achievement-reward (achievement-id uint))
  (let
    (
      (achievement-data (unwrap! (map-get? achievements { achievement-id: achievement-id }) (err ERR-NOT-FOUND)))
      (user-achievement (map-get? user-achievements { user: tx-sender, achievement-id: achievement-id }))
    )
    (begin
      ;; Check if achievement is unlocked but reward not claimed
      (asserts! (is-some user-achievement) (err ERR-NOT-FOUND))
      (asserts! (not (get reward-claimed (unwrap-panic user-achievement))) (err ERR-ALREADY-CLAIMED))
      (asserts! (get is-active achievement-data) (err ERR-INVALID-INPUT))
      
      (let
        (
          (reward-amount (get reward-amount achievement-data))
        )
        ;; Mint and transfer tokens
        (try! (ft-mint? pet-care-tokens reward-amount tx-sender))
        
        ;; Mark achievement reward as claimed
        (map-set user-achievements
          { user: tx-sender, achievement-id: achievement-id }
          (merge (unwrap-panic user-achievement) { reward-claimed: true })
        )
        
        ;; Update user total earned
        (match (map-get? user-rewards { user: tx-sender })
          user-data
            (map-set user-rewards
              { user: tx-sender }
              (merge user-data {
                total-earned: (+ (get total-earned user-data) reward-amount),
                achievements-unlocked: (+ (get achievements-unlocked user-data) u1)
              })
            )
          ;; If no user data exists, create it
          (map-set user-rewards
            { user: tx-sender }
            {
              total-earned: reward-amount,
              daily-streak: u0,
              longest-streak: u0,
              last-claim-day: u0,
              daily-claims-count: u0,
              achievements-unlocked: u1,
              lifetime-interactions: u0,
              bonus-multiplier: u1
            }
          )
        )
        
        ;; Record transaction
        (record-reward-transaction "achievement" reward-amount (get name achievement-data))
        
        ;; Update contract stats
        (var-set total-tokens-minted (+ (var-get total-tokens-minted) reward-amount))
        
        (ok reward-amount)
      )
    )
  )
)

;; Read-only function to get user rewards summary
(define-read-only (get-user-rewards (user principal))
  (match (map-get? user-rewards { user: user })
    user-data (ok user-data)
    (err ERR-NOT-FOUND)
  )
)

;; Read-only function to get user's token balance
(define-read-only (get-balance (user principal))
  (ok (ft-get-balance pet-care-tokens user))
)

;; Read-only function to check daily claim status
(define-read-only (get-daily-claim-status (user principal))
  (let
    (
      (current-day (/ stacks-block-height u144))
      (daily-data (map-get? daily-claims { user: user, day: current-day }))
    )
    (ok {
      current-day: current-day,
      claims-made: (default-to u0 (get claims-made daily-data)),
      can-claim: (< (default-to u0 (get claims-made daily-data)) MAX-DAILY-CLAIMS),
      total-earned-today: (default-to u0 (get total-earned daily-data))
    })
  )
)

;; Read-only function to get achievement details
(define-read-only (get-achievement-details (achievement-id uint))
  (match (map-get? achievements { achievement-id: achievement-id })
    achievement-data (ok achievement-data)
    (err ERR-NOT-FOUND)
  )
)

;; Read-only function to check user achievement status
(define-read-only (get-user-achievement-status (user principal) (achievement-id uint))
  (match (map-get? user-achievements { user: user, achievement-id: achievement-id })
    achievement-data (ok achievement-data)
    (err ERR-NOT-FOUND)
  )
)

;; Read-only function to get leaderboard
(define-read-only (get-leaderboard-entry (period uint) (rank uint))
  (map-get? leaderboard-entries { period: period, rank: rank })
)

;; Read-only function to get total supply of tokens
(define-read-only (get-total-supply)
  (ok (ft-get-supply pet-care-tokens))
)

;; Private helper functions for min/max
(define-private (min (a uint) (b uint))
  (if (<= a b) a b)
)

(define-private (max (a uint) (b uint))
  (if (>= a b) a b)
)

;; Private function to calculate streak bonus
(define-private (calculate-streak-bonus (streak uint))
  (if (>= streak u7)
    (+ u1 (min u5 (/ streak u7))) ;; Max 6x multiplier
    u1
  )
)

;; Private function to calculate new streak
(define-private (calculate-new-streak (user-data { total-earned: uint, daily-streak: uint, longest-streak: uint, last-claim-day: uint, daily-claims-count: uint, achievements-unlocked: uint, lifetime-interactions: uint, bonus-multiplier: uint }) (current-day uint))
  (let
    (
      (last-claim-day (get last-claim-day user-data))
      (current-streak (get daily-streak user-data))
    )
    (if (is-eq last-claim-day u0)
      u1 ;; First claim ever
      (if (is-eq last-claim-day (- current-day u1))
        (+ current-streak u1) ;; Consecutive day
        (if (is-eq last-claim-day current-day)
          current-streak ;; Same day, maintain streak
          u1 ;; Streak broken, start over
        )
      )
    )
  )
)

;; Private function to calculate interaction reward
(define-private (calculate-interaction-reward (interaction-type (string-ascii 16)) (multiplier uint))
  (let
    (
      (base-reward
        (if (is-eq interaction-type "feed")
          u20
          (if (is-eq interaction-type "play")
            u30
            (if (is-eq interaction-type "train")
              u50
              (if (is-eq interaction-type "rest")
                u15
                u25 ;; default
              )
            )
          )
        )
      )
    )
    (* base-reward multiplier)
  )
)

;; Private function to record reward transactions
(define-private (record-reward-transaction (reward-type (string-ascii 16)) (amount uint) (reason (string-ascii 32)))
  (let
    (
      (transaction-id (+ (mod stacks-block-height u10000) u1))
    )
    (map-set reward-history
      { user: tx-sender, transaction-id: transaction-id }
      {
        reward-type: reward-type,
        amount: amount,
        block-height: stacks-block-height,
        reason: reason
      }
    )
  )
)

;; Private function to check streak achievements
(define-private (check-streak-achievements (streak uint))
  (begin
    ;; Check 7-day streak achievement
    (if (and (>= streak u7) (is-none (map-get? user-achievements { user: tx-sender, achievement-id: u3 })))
      (map-set user-achievements
        { user: tx-sender, achievement-id: u3 }
        { unlocked-block: stacks-block-height, reward-claimed: false }
      )
      true
    )
    ;; More streak achievements can be added here
  )
)

;; Private function to check interaction-based achievements
(define-private (check-interaction-achievements (total-interactions uint))
  (begin
    ;; Check 10 interactions achievement
    (if (and (>= total-interactions u10) (is-none (map-get? user-achievements { user: tx-sender, achievement-id: u2 })))
      (map-set user-achievements
        { user: tx-sender, achievement-id: u2 }
        { unlocked-block: stacks-block-height, reward-claimed: false }
      )
      true
    )
    ;; Check 100 interactions achievement
    (if (and (>= total-interactions u100) (is-none (map-get? user-achievements { user: tx-sender, achievement-id: u4 })))
      (map-set user-achievements
        { user: tx-sender, achievement-id: u4 }
        { unlocked-block: stacks-block-height, reward-claimed: false }
      )
      true
    )
  )
)

