# Raksha Forenix - AI Forensic Engine

A full-stack, AI-powered digital forensics and reporting platform designed for deepfake detection, chain of custody verification, and automated cryptographic reporting. 

## Live Deployments
* **Frontend UI:** [Insert your Vercel Link Here]
* **Backend API:** [Insert your Render Link Here]

## Architecture & Tech Stack
* **Frontend Engine:** Flutter (Web)
* **Backend Core:** Python 3, FastAPI
* **Deployment:** Vercel (UI), Render (API)
* **Cryptographic Ledger:** Hash-chain integrity verification
* **Reporting:** Automated PDF generation via Ghostwriter engine

## Core Features
* **Chain of Custody:** Immutable, cryptographic tracking of all uploaded digital evidence.
* **Feature Extraction:** Deep analysis of digital artifacts and metadata.
* **AI Detection:** Advanced processing for anomaly and deepfake identification.
* **Automated Reporting:** Generates court-ready, mathematically verified PDF reports summarizing all forensic findings.

## Local Development Setup

**1. Clone the Repository**
git clone https://github.com/rahul14rx/raksha_forensic_proj.git

**2. Start the FastAPI Backend**
cd forensic_ai_engine
pip install -r requirements.txt
uvicorn main:new_app --host 127.0.0.1 --port 8000

**3. Start the Flutter Frontend**
cd forensic_ui
flutter pub get
flutter run -d chrome