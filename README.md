# Live Streaming iOS App

A Swift iOS app for social live streaming with paid viewer requests, CallKit integration, and a real-time engagement system.

---

## 📱 Overview

This app lets users host live streams, invite friends via Apple's CallKit API, and receive paid requests from viewers during the stream. It's a complete monetisation platform for creators.

---

## 🛠️ Tech Stack

- **Swift** – iOS frontend
- **Firebase** – Auth, Firestore, Cloud Functions, Storage
- **CallKit** – Apple's framework for VoIP and system-level calls
- **Stripe** – Payment processing
- **LiveKit** – Real-time streaming infrastructure

---

## ✨ Key Features

- **Live streaming** – Start a stream and broadcast to friends in real-time
- **CallKit invites** – Friends receive a system-level call when the stream starts; they tap to join instantly
- **Paid requests** – Viewers can pay to request dares, challenges, or actions during the stream
- **Virtual wallet** – Users earn and withdraw their streaming revenue
- **Push notifications** – Real-time updates for requests, earnings, and stream activity

---

## 🏗️ Architecture

Built on a **Firebase-first** backend:

- **Firestore** – Real-time data sync for streams, requests, and user data
- **Cloud Functions** – Serverless logic for payment processing, request handling, and earning calculations
- **Firebase Auth** – User authentication and session management
- **CallKit + PushKit** – Handles incoming stream invites even when the app is in the background

The backend architecture was originally built for a photo competition platform and was extended to support live streaming without requiring a rewrite—demonstrating the flexibility of the Firebase-based infrastructure.

---

## 📸 Screenshots

| Stream View | Request Sheet | Wallet |
|-------------|---------------|--------|
| <img width="300" alt="Stream View" src="https://github.com/user-attachments/assets/0bdeb74d-4a5e-474f-90e8-6887119deb92" /> | <img width="300" alt="Request Sheet" src="https://github.com/user-attachments/assets/7d6a1c7d-0a06-4650-8033-1560282d9c5f" /> | <img width="300" alt="Wallet" src="https://github.com/user-attachments/assets/6bd9c1db-84ee-4a65-9793-ee491b35eb6a" /> |

---

## 🔗 Related Repos

- [Streamer Menu Web](https://github.com/chisom123/streamer-menu-web) – Web order form for viewers to submit requests before a stream

---

## ⚙️ Setup

This project uses Firebase. To run it locally:

1. Clone the repo  
2. Create a Firebase project and enable Auth, Firestore, and Cloud Functions  
3. Add your `GoogleService-Info.plist` to the project root  
4. Open in Xcode and build

---

## 📈 Evolution

This project started as a photo competition app and pivoted to live streaming—proving the flexibility of the backend architecture. The core infrastructure (auth, wallet, real-time data) remained consistent across both iterations.
