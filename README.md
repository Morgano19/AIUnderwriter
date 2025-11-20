🩺 AIUnderwriter
================

📖 Overview
-----------

The **AIUnderwriter** is a sophisticated smart application written in the **Clarity** programming language, designed to implement an intelligent, decentralized health insurance underwriting system. It leverages **AI-driven risk assessment** principles to evaluate applicant health data, calculate dynamic premiums, and manage the full lifecycle of health insurance policies on the blockchain.

This application demonstrates a cutting-edge use of smart contract logic, integrating complex processes for risk modeling and policy administration, including:

-   **Risk Assessment:** Calculates an AI-driven risk score and assigns a risk level (Low, Medium, High, Critical) based on applicant data (age, BMI, pre-existing conditions, lifestyle).

-   **Dynamic Premium Calculation:** Determines the initial premium based on the calculated risk level and requested coverage amount.

-   **Policy Management:** Handles application submission, policy issuance, premium payment, and tracks policy status (Pending, Active, Suspended, Expired).

-   **Claims Processing:** Manages claim submission, incorporates a basic **AI-assisted fraud score**, and processes claims (approval/rejection) with owner-only authority.

-   **Model Governance:** Allows the application owner to initialize and update the weights of the AI risk model, simulating model retraining and governance.

-   **Advanced Recalculation:** Includes a public function for **dynamic premium recalculation** based on claims history, policy performance, and updated health/behavioral data, ensuring fair and sustainable pricing.

* * * * *

⚙️ Application Structure and Data Models
----------------------------------------

### Data Maps and Variables

| Map/Variable | Type | Description |
| --- | --- | --- |
| `applicants` (map) | `{ applicant: principal } -> { ...health data }` | Stores detailed health metrics, AI risk scores, and application timestamps for applicants. |
| `policies` (map) | `{ policy-id: uint } -> { ...policy details }` | Stores all issued policy details, including holder, premium, coverage, duration, status, and claims history. |
| `holder-policies` (map) | `{ holder: principal } -> { policy-id: uint }` | Provides a quick lookup from a policy holder's principal to their current policy ID. |
| `claims` (map) | `{ claim-id: uint } -> { ...claim details }` | Records detailed information for submitted claims, including amount, type, AI fraud score, and resolution status. |
| `ai-model-weights` (map) | `{ parameter: (string-ascii 32) } -> { weight: uint }` | Stores the weights (simulated model parameters) used by the risk assessment algorithm. |
| `policy-counter` (var) | `uint` | Tracks the total number of policies issued. |
| `claim-counter` (var) | `uint` | Tracks the total number of claims submitted. |
| `total-premiums-collected` (var) | `uint` | Aggregated value of all premiums paid to the application. |
| `total-claims-paid` (var) | `uint` | Aggregated value of all claims paid out by the application. |
| `ai-model-version` (var) | `uint` | Tracks the version of the AI risk model (incremented when weights are updated). |

### Constants

-   **Owner/Error Control:** `contract-owner`, `err-owner-only`, `err-not-found`, `err-unauthorized`, etc.

-   **Risk Levels (uint):** `risk-low` (u1), `risk-medium` (u2), `risk-high` (u3), `risk-critical` (u4).

-   **Policy Statuses (uint):** `status-pending` (u0), `status-active` (u1), `status-suspended` (u2), `status-expired` (u3).

* * * * *

📝 Function Definitions
-----------------------

### Public Functions (`define-public`)

These functions modify the application state (read/write access) and require a transaction fee. They represent the main transactional logic of the insurance system.

| Function | Sender Authorization | Description |
| --- | --- | --- |
| `initialize-ai-model` | `contract-owner` | Sets the initial default weights for the AI risk assessment model. |
| `submit-application` | Any Principal | Allows an applicant to submit their health data. Calculates and stores their initial **AI risk score** and **risk level**. |
| `issue-policy` | `contract-owner` | Approves an application, calculates the initial premium, and issues a new policy with defined coverage and duration. |
| `pay-premium` | Policy Holder | Allows the policy holder to pay the required premium amount to keep the policy active. Updates `total-premiums-collected`. |
| `submit-claim` | Policy Holder | Submits a claim against an active policy. Calculates a simulated **AI fraud score** and sets the claim status to pending. |
| `process-claim` | `contract-owner` | Resolves a pending claim. Approval requires owner consent **AND** a low AI fraud score (<70). Updates claims and policy records. |
| `update-ai-weights` | `contract-owner` | Allows the owner to adjust the importance (weights) of specific health parameters in the risk model, simulating model retraining and improvement. |
| `recalculate-premium-with-ai-analysis` | Owner or Policy Holder | Performs an **advanced dynamic risk reassessment**. Calculates a new premium based on claims history, behavioral data (`new-health-score`), and policy performance, with defined adjustment caps. |

* * * * *

### Private Functions (`define-private`)

These functions are internal helpers used exclusively by the public functions to perform complex calculations and validation logic. They cannot be called directly by external users.

| Function | Used By | Description |
| --- | --- | --- |
| `calculate-ai-risk-score` | `submit-application`, `recalculate-premium-with-ai-analysis` | Computes the weighted sum of health metrics (age, BMI, conditions, lifestyle) using the current AI model weights to generate a score. |
| `get-risk-level` | `submit-application` | Maps the raw AI risk score to one of the four defined risk categories (`risk-low` to `risk-critical`) using fixed thresholds. |
| `calculate-premium` | `issue-policy` | Determines the policy premium by applying a risk-level-based multiplier (Base Rate) to the requested `coverage-amount`. |
| `validate-health-data` | `submit-application` | Ensures that the submitted health metrics (age, BMI, etc.) are within acceptable, realistic boundary ranges (e.g., age 18-100). |

* * * * *

### Read-Only Functions (`define-read-only`)

These functions allow external entities to query the application state (read-only access) without requiring a transaction signature or incurring gas fees. They are vital for transparency and auditing.

| Function | Description |
| --- | --- |
| `get-applicant-data (applicant principal)` | Retrieves the health data, AI risk score, and risk level recorded for a specific applicant. |
| `get-policy-details (policy-id uint)` | Retrieves all stored details for a given policy ID, including holder, premium, coverage, and claims history. |
| `get-claim-details (claim-id uint)` | Retrieves the full details of a specific claim, including amount, fraud score, and resolution status. |
| `get-contract-stats` | Provides summary statistics for the entire application, including `total-policies`, `premiums-collected`, `claims-paid`, and the current `ai-model-version`. |

* * * * *

🛠️ Deployment and Usage
------------------------

### Prerequisites

-   A Stacks 2.x blockchain environment.

-   A Clarity wallet (e.g., Hiro Wallet) for signing transactions.

-   The application must be deployed by the designated `contract-owner`.

### Key Functions Flow

1.  **Contract Owner:** Call `(initialize-ai-model)` to set initial AI weights.

2.  **Applicant:** Call `(submit-application age bmi pre-existing lifestyle)` to get assessed.

3.  **Contract Owner:** After application review, call `(issue-policy applicant coverage-amount duration-blocks)` to create the policy.

4.  **Policy Holder:** Call `(pay-premium policy-id amount)` to activate and maintain coverage.

5.  **Policy Holder:** Call `(submit-claim policy-id claim-amount claim-type)` when a medical event occurs.

6.  **Contract Owner:** Call `(process-claim claim-id approved)` to approve or reject the pending claim.

7.  **Owner/Holder:** Call `(recalculate-premium-with-ai-analysis policy-id new-health-score behavioral-improvement)` to adjust future premiums based on performance and new data.

* * * * *

🔒 Security and Governance
--------------------------

### Role-Based Access Control

-   **Owner-Only:** The `contract-owner` is the only entity authorized to perform administrative tasks like initializing/updating model weights, issuing policies, and resolving claims.

-   **Policy Holder Only:** Only the policy holder can pay premiums and submit claims.

-   **Shared Authority:** Both the owner and the policy holder can initiate premium recalculation.

### AI Fraud Guardrail

The `process-claim` function includes an essential security guardrail: even if the `contract-owner` attempts to manually approve a claim (`approved: true`), the claim will be rejected if the simulated `ai-fraud-score` is **70 or higher**. This hardcoded limit ensures the AI model's assessment has a mandatory check against malicious or high-risk claims, enhancing the application's financial sustainability.

* * * * *

🤝 Contribution
---------------

We welcome contributions to enhance the functionality and security of the **AIUnderwriter**. Please submit pull requests or open issues on the GitHub repository. Areas for potential improvement include:

-   **Oracle Integration:** Replacing the simulated fraud score calculation with a secure call to a decentralized AI Oracle for real-world risk/fraud scoring.

-   **Decentralized Governance:** Allowing policy holders or an approved committee to vote on updates to AI model weights or policy parameters, moving away from the single `contract-owner` model.

* * * * *

📜 License
----------

```
MIT License

Copyright (c) 2025 AIUnderwriter Developers

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

```
