# Core Data Model Documentation

This document describes the Core Data entities required for the DigitalFormsApp.

## Required Entities

Create a new Core Data model file named `DigitalFormsApp.xcdatamodeld` with the following entities:

### 1. User Entity

| Attribute | Type | Optional | Notes |
|-----------|------|----------|-------|
| id | UUID | No | Primary identifier |
| name | String | Yes | User's display name |
| email | String | Yes | User's email address |
| role | String | Yes | User's role (Operator, Supervisor, etc.) |

### 2. FormTemplate Entity

| Attribute | Type | Optional | Notes |
|-----------|------|----------|-------|
| id | UUID | No | Primary identifier |
| name | String | Yes | Template name |
| templateDescription | String | Yes | Template description |
| category | String | Yes | Category (Safety, Permits, etc.) |
| createdAt | Date | Yes | Creation timestamp |
| isActive | Boolean | No | Whether template is active |
| version | Integer 16 | No | Template version number |

**Relationships:**
- `fields`: To-Many relationship to `TemplateField` (inverse: `template`)

### 3. TemplateField Entity

| Attribute | Type | Optional | Notes |
|-----------|------|----------|-------|
| id | UUID | No | Primary identifier |
| label | String | Yes | Field label |
| type | String | Yes | Field type (text, number, date, etc.) |
| isRequired | Boolean | No | Whether field is required |
| order | Integer 16 | No | Display order |
| options | String | Yes | Comma-separated options for dropdowns |

**Relationships:**
- `template`: To-One relationship to `FormTemplate` (inverse: `fields`)

### 4. FormEntity Entity

| Attribute | Type | Optional | Notes |
|-----------|------|----------|-------|
| id | UUID | No | Primary identifier |
| templateId | UUID | Yes | Reference to template |
| title | String | Yes | Form title |
| createdAt | Date | Yes | Creation timestamp |
| updatedAt | Date | Yes | Last update timestamp |
| submittedAt | Date | Yes | Submission timestamp |
| status | String | Yes | Form status (draft, submitted, etc.) |
| syncStatus | String | Yes | Sync status (pending, synced, failed) |
| createdById | UUID | Yes | User who created the form |
| latitude | Double | No | GPS latitude |
| longitude | Double | No | GPS longitude |

**Relationships:**
- `fields`: To-Many relationship to `FormField` (inverse: `form`)
- `signatures`: To-Many relationship to `Signature` (inverse: `form`)
- `attachments`: To-Many relationship to `Attachment` (inverse: `form`)
- `approvals`: To-Many relationship to `Approval` (inverse: `form`)

### 5. FormField Entity

| Attribute | Type | Optional | Notes |
|-----------|------|----------|-------|
| id | UUID | No | Primary identifier |
| fieldId | UUID | Yes | Reference to template field |
| label | String | Yes | Field label |
| type | String | Yes | Field type |
| value | String | Yes | Field value |
| isRequired | Boolean | No | Whether field is required |
| order | Integer 16 | No | Display order |
| options | String | Yes | Dropdown options |

**Relationships:**
- `form`: To-One relationship to `FormEntity` (inverse: `fields`)

### 6. Signature Entity

| Attribute | Type | Optional | Notes |
|-----------|------|----------|-------|
| id | UUID | No | Primary identifier |
| imageData | Binary Data | Yes | Signature image data |
| signedAt | Date | Yes | Signing timestamp |
| signedById | UUID | Yes | User who signed |
| signerName | String | Yes | Signer's name |
| signerRole | String | Yes | Signer's role |

**Relationships:**
- `form`: To-One relationship to `FormEntity` (inverse: `signatures`)

### 7. Attachment Entity

| Attribute | Type | Optional | Notes |
|-----------|------|----------|-------|
| id | UUID | No | Primary identifier |
| imageData | Binary Data | Yes | Photo data |
| caption | String | Yes | Photo caption |
| capturedAt | Date | Yes | Capture timestamp |
| latitude | Double | No | GPS latitude |
| longitude | Double | No | GPS longitude |

**Relationships:**
- `form`: To-One relationship to `FormEntity` (inverse: `attachments`)

### 8. Approval Entity

| Attribute | Type | Optional | Notes |
|-----------|------|----------|-------|
| id | UUID | No | Primary identifier |
| approvedAt | Date | Yes | Approval timestamp |
| approvedById | UUID | Yes | Approver's user ID |
| approverName | String | Yes | Approver's name |
| comments | String | Yes | Approval comments |
| decision | String | Yes | Decision (approved/rejected) |

**Relationships:**
- `form`: To-One relationship to `FormEntity` (inverse: `approvals`)

## Setup Instructions

1. In Xcode, create a new Core Data model file: File > New > File > Core Data > Data Model
2. Name it `DigitalFormsApp.xcdatamodeld`
3. Add each entity listed above with the specified attributes
4. Configure all relationships as bidirectional with proper inverse relationships
5. For Binary Data attributes (imageData), consider enabling "Allows External Storage" for better performance

## Migration Notes

If updating from a previous version:
- Enable lightweight migration in `NSPersistentContainer` setup
- The `NSPersistentHistoryTrackingKey` option is already enabled in the code
