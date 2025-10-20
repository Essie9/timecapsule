# ⏰ Time Capsule - Decentralized Time-Locked Digital Vault

## Overview

**Time Capsule** is an innovative, production-ready Clarity smart contract that enables users to create time-locked digital vaults containing messages, STX tokens, and metadata that can only be accessed after a specified unlock time. Perfect for gifts, inheritance planning, future messages, milestone celebrations, and more.

## 🎯 The Revolutionary Concept

### What Makes Time Capsule Special:
- **Guaranteed Future Delivery**: Messages and assets locked until specific block height
- **Zero Trust Required**: Smart contract enforces time locks automatically
- **Multi-Purpose**: Personal messages, gifts, inheritance, business escrow
- **Group Capsules**: Send the same message to multiple recipients
- **Public Registry**: Optional public capsules for community events
- **Complete Auditability**: Full access logs for security tracking

### Real-World Problems It Solves:

❌ **Traditional Method Issues:**
- Email scheduled sends can be deleted/cancelled
- Third-party services can shut down
- Physical time capsules can be lost or damaged
- Trust required in intermediaries
- No proof of delivery time

✅ **Time Capsule Solutions:**
- Blockchain-guaranteed delivery
- Immutable once created
- Cryptographically secure
- Trustless execution
- Permanent access logs

## 🌟 Innovative Features

### 1. **Smart Time-Locking**
- Lock messages and STX for any future block height
- Automatically enforced by blockchain consensus
- Recipient cannot access until unlock time
- Creator can extend time before unlock
- Emergency withdraw with strict conditions

### 2. **Flexible Capsule Types**
- **Personal**: One-to-one messages
- **Group**: Same message to multiple people
- **Public**: Community-viewable capsules
- **Gift**: STX + message combinations
- **Milestone**: Unlock on specific future dates

### 3. **Rich Content Storage**
- Messages up to 1,000 UTF-8 characters
- Optional metadata (500 characters)
- STX token storage
- Capsule type categorization
- Creator notes and context

### 4. **Advanced Security**
- ✅ Recipient-only access after unlock
- ✅ Creator authentication for modifications
- ✅ Access logging for audit trails
- ✅ Emergency withdraw with time restrictions
- ✅ 10% penalty for early cancellation
- ✅ Contract pause mechanism
- ✅ Per-user capsule limits (100 max)

### 5. **User Experience**
- Preview unlocked capsules before opening
- Add funds to existing capsules
- Update messages before unlock
- Extend unlock times
- Track all your capsules easily
- Public/private visibility options

### 6. **Optimized Performance**
- Efficient user capsule indexing
- O(1) lookups for all operations
- Minimal storage footprint
- Gas-optimized calculations
- Batch group capsule creation

## 💡 Powerful Use Cases

### 1. **Future Gift to Children**
```clarity
;; Lock 1000 STX for your child's 18th birthday (in ~6 years)
(contract-call? .time-capsule create-capsule
  'ST1CHILD... ;; child's wallet
  u"Happy 18th Birthday! This is from when you were 12. Use this for college or your dreams. Love, Dad"
  u1000000000 ;; 1000 STX
  u315360 ;; ~6 years in blocks
  "gift"
  false ;; private
  (some u"Birthday milestone - opened on your special day"))
```

### 2. **Business Escrow**
```clarity
;; Lock payment for 30-day project milestone
(contract-call? .time-capsule create-capsule
  'ST1FREELANCER...
  u"Payment for Q4 website redesign project. Deliverables confirmed."
  u50000000 ;; 50 STX
  u4320 ;; ~30 days
  "business"
  false
  (some u"Project ID: WEB-2025-Q4"))
```

### 3. **New Year's Time Capsule**
```clarity
;; Public community capsule for next New Year
(contract-call? .time-capsule create-capsule
  'ST1COMMUNITY...
  u"2025 was an incredible year for our DAO. Remember when we launched the NFT collection? Here's to 2026!"
  u0 ;; no STX, just message
  u52560 ;; 1 year
  "community"
  true ;; PUBLIC - anyone can view after unlock
  (some u"Annual DAO Retrospective"))
```

### 4. **Digital Inheritance**
```clarity
;; Create inheritance message with access keys/info
(contract-call? .time-capsule create-capsule
  'ST1HEIR...
  u"If you're reading this, I'm gone. Here are wallet recovery phrases and account info: [encrypted data]. Love you always."
  u5000000000 ;; 5000 STX
  u525600 ;; ~10 years (failsafe)
  "inheritance"
  false
  (some u"Estate planning - update annually"))
```

### 5. **Couple's Anniversary**
```clarity
;; Lock romantic message for 1-year anniversary
(contract-call? .time-capsule create-capsule
  'ST1PARTNER...
  u"One year ago today, we got married. I love you more each day. Here's to many more years together. ❤️"
  u10000000 ;; 10 STX for anniversary dinner
  u52560 ;; 1 year
  "personal"
  false
  (some u"First Anniversary"))
```

### 6. **Group Employee Bonus**
```clarity
;; Send year-end bonuses to team members
(contract-call? .time-capsule create-group-capsule
  (list 'ST1EMP1... 'ST1EMP2... 'ST1EMP3... 'ST1EMP4... 'ST1EMP5...)
  u"Thank you for an incredible 2025! Your hard work made this possible. Enjoy your bonus!"
  u20000000 ;; 20 STX per person
  u720 ;; unlock in 5 days (New Year)
  (some u"2025 Year-End Team Bonus"))
```

### 7. **Graduation Gift**
```clarity
;; Parent locks funds for college graduation
(contract-call? .time-capsule create-capsule
  'ST1STUDENT...
  u"Congratulations on graduating! You worked so hard. This is for your next adventure. We're so proud!"
  u500000000 ;; 500 STX
  u210240 ;; 4 years
  "milestone"
  false
  (some u"College Graduation Fund"))
```

## 🏗️ Technical Architecture

### Data Structures

**Capsule Structure**
```clarity
{
  creator: principal,              // Who created the capsule
  recipient: principal,            // Who can open it
  message: string-utf8 1000,       // The locked message
  stx-amount: uint,                // STX locked in capsule
  unlock-height: uint,             // Block height when unlockable
  created-at: uint,                // Creation block height
  opened-at: optional uint,        // When it was opened (if ever)
  is-opened: bool,                 // Open status
  capsule-type: string-ascii 20,   // gift/personal/business/etc
  metadata: optional string-utf8   // Additional context/notes
}
```

**Access Log**
```clarity
{
  accessed-by: principal,          // Who accessed
  access-time: uint,               // When (block height)
  action: string-ascii 20          // What action (created/opened/previewed)
}
```

### Security Model

**Time-Lock Enforcement**
- Unlock height checked on every open attempt
- Block height comparison: `stacks-block-height >= unlock-height`
- No backdoors or override mechanisms
- Creator cannot bypass lock (except emergency conditions)

**Emergency Withdraw Conditions** (Both must be true):
1. Capsule unlock is >1 year away (`> 52560 blocks`), OR
2. Capsule was created within last 24 hours (`< 144 blocks`)

This prevents abuse while allowing genuine emergencies.

**Cancellation Penalty**
- 10% fee deducted from STX amount
- Only available before unlock time
- Prevents spam/abuse of the system
- Penalties collected in contract for platform sustainability

## 📖 Complete Usage Guide

### Creating Capsules

**Basic Personal Capsule**
```clarity
(contract-call? .time-capsule create-capsule
  'ST1RECIPIENT...                    ;; recipient wallet
  u"Your message here"                ;; message content
  u10000000                           ;; 10 STX
  u52560                              ;; blocks until unlock (~1 year)
  "personal"                          ;; capsule type
  false                               ;; private (not public)
  (some u"Optional context notes"))   ;; metadata
;; Returns: (ok u1) - capsule ID
```

**Group Capsule**
```clarity
(contract-call? .time-capsule create-group-capsule
  (list 'ST1ADDR1... 'ST1ADDR2... 'ST1ADDR3...)  ;; up to 10 recipients
  u"Shared message for everyone"                 ;; same message to all
  u5000000                                        ;; 5 STX per person
  u4320                                           ;; unlock in 30 days
  (some u"Group gift occasion"))                 ;; metadata
;; Returns: (ok (list u1 u2 u3)) - list of created capsule IDs
```

### Managing Capsules

**Check Time Until Unlock**
```clarity
(contract-call? .time-capsule time-until-unlock u1)
;; Returns: (ok u25000) - blocks remaining, or u0 if unlocked
```

**Preview Unlocked Capsule** (recipient only)
```clarity
(contract-call? .time-capsule preview-capsule u1)
;; Returns full capsule details if unlocked and you're the recipient
```

**Add More STX to Existing Capsule** (creator only)
```clarity
(contract-call? .time-capsule add-funds-to-capsule u1 u5000000)
;; Adds 5 more STX to capsule #1
```

**Update Message Before Unlock** (creator only)
```clarity
(contract-call? .time-capsule update-message 
  u1 
  u"Updated message with new information")
;; Only works before unlock time
```
