# Gift Card API - Postman Collection & Environments

This directory contains the complete Postman workspace configuration for testing and interacting with the Gift Card API across Local and Production environments.

---

## 📁 Files Included

| File | Purpose | Base URL |
| :--- | :--- | :--- |
| `gift_card_api.postman_collection.json` | Complete API collection with automated tests and pre-configured request payloads. | `{{baseUrl}}` |
| `gift_card_api.production.postman_environment.json` | Production environment pointing to live server with seed credentials. | `https://etymologies.duckdns.org/egift/api/v1` |
| `gift_card_api.local.postman_environment.json` | Local development environment for `localhost:3000`. | `http://localhost:3000/api/v1` |

---

## 🚀 Quick Start Guide

### 1. Import Files into Postman
1. Open **Postman**.
2. Click **Import** (top left).
3. Drag & drop or select all three JSON files from the `postman/` directory:
   - `gift_card_api.postman_collection.json`
   - `gift_card_api.production.postman_environment.json`
   - `gift_card_api.local.postman_environment.json`

### 2. Select Your Environment
In the upper right corner of Postman, open the environment dropdown:
- Select **Gift Card API - Production** to test the live server (`https://etymologies.duckdns.org/egift/api/v1`).
- Select **Gift Card API - Local** to test locally (`http://localhost:3000/api/v1`).

### 3. Verify Connectivity (Ping Health Check)
1. Open folder `00. Health Check`.
2. Click **1. Ping Health Check** (`GET {{baseUrl}}/ping`).
3. Click **Send**.
4. Expected Response:
   ```json
   {
     "ping": "pong",
     "timestamp": "2026-10-20T10:58:59Z"
   }
   ```
5. All 3 Postman tests should pass automatically:
   - `Status code is 200 OK`
   - `Response returns pong`
   - `Response time is acceptable (< 1000ms)`

### 4. Authenticate & Auto-Capture JWT Token
Run either login request in `01. Authentication Flow`:
- **Admin Login**: Uses `{{admin_email}}` and `{{admin_password}}`.
- **Client Login**: Uses `{{client_email}}` and `{{client_password}}`.

The Postman Test script will automatically extract `jsonData.token` and store it in the active environment variable `authToken`:
```javascript
pm.collectionVariables.set('authToken', jsonData.token);
pm.environment.set('authToken', jsonData.token);
```
All subsequent authenticated endpoints in the collection (`Bearer {{authToken}}`) are immediately ready to run without manual copy-pasting.

---

## 📋 Collection Structure

```
Gift Card API
├── 00. Health Check
│   └── 1. Ping Health Check
├── 01. Authentication Flow
│   ├── 1. Admin Login (AUTH-1, ADM-1)
│   ├── 2. Client Login (AUTH-1, CLI-1)
│   └── 3. Logout (AUTH-9)
├── 02. Admin - User & Client Management
│   ├── 1. Create Secondary Admin (AUTH-3)
│   ├── 2. Create Client (AUTH-4, ADM-5)
│   ├── 3. List Clients (ADM-5)
│   ├── 4. Get Client by ID (ADM-5)
│   ├── 5. Update Client (ADM-5, LOG-2)
│   └── 6. Toggle Client State (ADM-9, AUTH-8)
├── 03. Admin - Brand Catalog Management
│   ├── 1. Create Brand (ADM-2)
│   ├── 2. List Brands (ADM-2)
│   ├── 3. Get Brand by ID (ADM-2)
│   ├── 4. Update Brand (ADM-2, LOG-2)
│   └── 5. Toggle Brand State (ADM-4)
├── 04. Admin - Product Catalog & Access Permissions
│   ├── 1. Create Product (ADM-3)
│   ├── 2. List Products (ADM-3)
│   ├── 3. Get Product by ID (ADM-3)
│   ├── 4. Update Product (ADM-3, LOG-2)
│   ├── 5. Toggle Product State (ADM-4, LOG-1)
│   ├── 6. Assign Product Access to Client (ADM-6)
│   ├── 7. List Client Product Permissions (ADM-6)
│   ├── 8. Revoke Product Access from Client (ADM-6)
│   └── 9. Soft Delete Product (ADM-3)
├── 05. Client - Catalog Browsing & Card Lifecycle
│   ├── 1. Client Browse Catalog (CLI-2)
│   ├── 2. Issue Gift Card (CLI-3, CLI-4)
│   ├── 3. Retry Card Issuance (Safe Idempotency Check CLI-4)
│   ├── 4. List Issued Cards (CLI-1)
│   ├── 5. Get Card Details (CLI-1)
│   └── 6. Cancel Issued Card (CLI-6)
├── 06. Admin - Audit Logs & Reporting
│   ├── 1. List Audit Logs (ADM-7, LOG-5)
│   ├── 2. Filter Audit Logs (LOG-5)
│   ├── 3. Admin Report by Brand (REP-1)
│   └── 4. Admin Report by Client (REP-2)
└── 07. Client - Reports
    ├── 1. Client Spending Report (REP-3, CLI-7)
    └── 2. Client Cancellation Report (REP-3, CLI-7)
```

---

## 🔑 Default Seed Credentials

| Role | Email | Password |
| :--- | :--- | :--- |
| **Admin** | `admin@example.com` | `Admin@12345` |
| **Client** | `client1@example.com` | `Client@12345` |
| **Client (Inactive)** | `client2@example.com` | `Client@12345` |
