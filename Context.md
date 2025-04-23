# FitFi - Context.md

## 🔥 Project Overview

**FitFi** is a blockchain-powered social fitness challenge platform where users stake $TGT tokens to compete in fun, predefined fitness duels like “Step Showdown” or “Stake & Flex.” Winners are determined based on fitness data (mocked in MVP), and smart contracts handle rewards trustlessly.

FitFi is being built for the **Sui Overflow 2025 Hackathon**, with over $500K in prizes and the chance to get incubated and funded.

---

## 🧩 Problem Statement

Fitness is more engaging when social and competitive. Web2 fitness apps lack meaningful incentives for consistency and performance. FitFi solves this by letting users:

- **Stake tokens**
- **Compete in fair duels**
- **Win or lose based on data**
- **Earn rewards and reputation**

---

## 💡 Core Features (MVP)

### 1. 🧠 Preset Challenges

Users choose from a list of curated challenge types:
- 🥾 **Step Showdown**: Highest steps in 24h wins
- 🧘 **Stake & Flex**: Longest step streak over 3 days
- 🚀 **Speed Steps**: First to reach 10K steps
- 🔁 **Sync Showdown**: Best avg over 3 days

Each preset defines:
- Duration
- Rules
- Stake range

### 2. 🎮 Challenge Flow

1. User selects a challenge
2. Clicks **“Stake & Find Opponent”** or **“Challenge a Friend”**
3. Stakes $TGT (mock)
4. Opponent accepts → smart contract is deployed
5. Fitness data is **mocked for now**
6. At the end, winner is determined and rewarded automatically

### 3. 🔐 Smart Contract Logic

- Built on **Sui Move**
- Challenge contract handles:
  - Token escrow
  - Challenge timer
  - Fitness data submission (mocked)
  - Winner verification
  - Payout/refund

---

## 🛠️ Tech Stack

### 🌐 Frontend (WebApp)
- **Next.js 15**
- TailwindCSS
- Wagmi / Sui Wallet Adapter
- React Toasts / Framer Motion for UI polish
- Fully mobile-friendly layout

### ⚙️ Backend
- Node.js + Express (for matchmaking & mock data)
- MongoDB (if user profiles needed)
- Mock fitness data generator (randomized step data per user)

### 📜 Smart Contracts
- **Sui Move** smart contracts
- Handles staking, match creation, result resolution, payouts

---

## 🏗️ Architecture & UX Plan

### 🧭 Pages

1. **Landing Page**
   - CTA: “Connect Wallet”
   - List of challenges with icons and descriptions

2. **Challenge Detail Page**
   - Show rules, duration, stake range
   - Buttons: “Stake & Find Opponent” / “Challenge Friend”

3. **My Duels Page**
   - List of ongoing and past duels
   - Result screens with animations and toasts

---

## 🚦 Roadmap & Timeline

### Week 1: Setup & Smart Contract

- [ ] Setup repo and monorepo structure
- [ ] Write and test Sui Move contracts
- [ ] Wallet connect & mock staking flow

### Week 2: Frontend + Backend

- [ ] Challenge list UI
- [ ] Matchmaking and challenge creation
- [ ] Backend mock for fitness data per duel
- [ ] Sync contracts with frontend state

### Week 3: Polish & Submit

- [ ] Animations, toasts, results screen
- [ ] Submission video + pitch deck
- [ ] Deploy frontend and contracts
- [ ] Submit to hackathon

---

## 🎨 Branding Plan

- Fun, social, gamified look (think Chess.com × Step App)
- Use emojis and icons to make each challenge pop
- Animations for win/loss
- Color palette: Green (growth), Blue (trust), Purple (energy)

---

## 🏁 Track Submission

🎯 **Payments & Wallets** (Top pick)  
**Why?** — You’re staking, rewarding, and handling payout flows — core infra for decentralized fitness economies.

Could also optionally qualify for:
- **Entertainment & Culture**
- **Explorations**

---

## ⚠️ MVP Note

For this hackathon, **fitness data is mocked** to simulate step counts.

Real-world integration with **Google Fit / Apple Health** will be explored post-MVP using OAuth + Sensor APIs.

---

## 🙌 Summary

FitFi turns fitness into a stake-to-compete social sport. It gamifies health with real value using blockchain and preset duels. Whether you challenge a friend or match with a stranger, your steps become your score — and your stake becomes your prize.

