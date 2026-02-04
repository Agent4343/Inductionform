# DigitalFormsApp API Backend

Secure Node.js/Express API for DigitalFormsApp iOS application.

## Security Features

- **Authentication**: JWT with refresh token rotation
- **Password Security**: bcrypt hashing (cost factor 12)
- **SQL Injection Prevention**: Parameterized queries only
- **Rate Limiting**: 100 req/15min (10 for auth endpoints)
- **HTTP Security Headers**: Helmet middleware
- **CORS**: Configurable allowed origins
- **Input Validation**: express-validator on all endpoints
- **Audit Logging**: All actions tracked
- **File Upload Security**: Type validation, size limits, image processing

## Quick Start

### Prerequisites
- Node.js 18+
- PostgreSQL 14+

### Local Development

```bash
# Install dependencies
npm install

# Copy environment file
cp .env.example .env

# Edit .env with your settings
nano .env

# Run database migration
npm run db:migrate

# Start development server
npm run dev
```

## Deploy to Railway

### 1. Create Railway Project

```bash
# Install Railway CLI
npm install -g @railway/cli

# Login
railway login

# Initialize project
railway init
```

### 2. Add PostgreSQL

```bash
# Add PostgreSQL database
railway add

# Select PostgreSQL from the list
```

### 3. Set Environment Variables

In Railway Dashboard or CLI:

```bash
railway variables set JWT_SECRET=$(openssl rand -hex 64)
railway variables set NODE_ENV=production
railway variables set ALLOWED_ORIGINS=https://your-ios-app-domain.com
```

### 4. Deploy

```bash
# Deploy to Railway
railway up
```

### 5. Run Migrations

```bash
# Run database migration
railway run npm run db:migrate
```

## API Endpoints

### Authentication (`/api/auth`)
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /register | Create new account |
| POST | /login | Login, get tokens |
| POST | /refresh | Refresh access token |
| POST | /logout | Logout, revoke tokens |
| DELETE | /account | Delete account (GDPR) |

### Forms (`/api/forms`)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | / | List user's forms |
| POST | / | Create new form |
| GET | /:id | Get form details |
| PUT | /:id | Update form |
| DELETE | /:id | Delete form |
| POST | /:id/submit | Submit for approval |
| POST | /:id/approve | Approve form |
| POST | /:id/reject | Reject form |
| POST | /:id/share | Share form with others |
| POST | /:id/signatures | Add signature |

### Templates (`/api/templates`)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | / | List templates |
| POST | / | Create template |
| GET | /:id | Get template |
| PUT | /:id | Update template |
| DELETE | /:id | Delete template |
| POST | /:id/duplicate | Copy template |

### Uploads (`/api/uploads`)
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /photo | Upload photo |
| POST | /signature | Upload signature |
| POST | /document | Upload document |
| POST | /form/:id/attachment | Add form attachment |
| DELETE | /:type/:filename | Delete file |

### Users (`/api/users`)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /me | Get profile |
| PUT | /me | Update profile |
| PUT | /me/password | Change password |
| GET | /me/notifications | Get notifications |
| GET | / | List org users (admin) |
| POST | /invite | Invite user (admin) |
| PUT | /:id/role | Change role (admin) |
| PUT | /:id/deactivate | Deactivate user (admin) |

## Database Schema

```
users
├── id (UUID, PK)
├── email (unique)
├── password_hash
├── name
├── role
├── organization_id (FK)
└── is_active, email_verified, timestamps

organizations
├── id (UUID, PK)
├── name
├── slug (unique)
├── owner_id (FK → users)
└── settings (JSONB)

forms
├── id (UUID, PK)
├── template_id (FK)
├── title
├── status
├── fields (JSONB)
├── created_by, assigned_to (FK → users)
└── latitude, longitude, timestamps

form_templates
├── id (UUID, PK)
├── name, description, category
├── fields (JSONB)
├── settings (JSONB)
├── is_public, version
└── created_by, organization_id

form_signatures
├── form_id (FK)
├── signer_name, signer_email
├── signature_data/url
├── ip_address, user_agent
└── signed_at, witness info

form_attachments
├── form_id (FK)
├── file_name, file_type, file_size
├── file_url, thumbnail_url
├── latitude, longitude
└── uploaded_by, created_at

workflow_rules
├── name, trigger_event
├── conditions (JSONB)
├── actions (JSONB)
└── is_active

audit_logs
├── user_id, action
├── resource_type, resource_id
├── old_values, new_values
├── ip_address, user_agent
└── created_at
```

## iOS Integration

Update your iOS app's `SyncManager`:

```swift
class SyncManager {
    private let baseURL = "https://your-app.railway.app/api"

    func login(email: String, password: String) async throws -> AuthResponse {
        let url = URL(string: "\(baseURL)/auth/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["email": email, "password": password])

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }

    func submitForm(_ form: FormEntity) async throws {
        let url = URL(string: "\(baseURL)/forms")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let formData = FormSubmission(
            templateId: form.templateId,
            title: form.title,
            fields: form.fieldsArray.map { ... },
            latitude: form.latitude,
            longitude: form.longitude
        )
        request.httpBody = try JSONEncoder().encode(formData)

        let (_, response) = try await URLSession.shared.data(for: request)
        // Handle response
    }
}
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| DATABASE_URL | Yes | PostgreSQL connection string |
| JWT_SECRET | Yes | Secret for JWT signing (64+ chars) |
| NODE_ENV | Yes | `development` or `production` |
| ALLOWED_ORIGINS | Yes | Comma-separated CORS origins |
| PORT | No | Server port (default: 3000) |
| BCRYPT_ROUNDS | No | Password hash rounds (default: 12) |

## Production Checklist

- [ ] Set strong JWT_SECRET (64+ random characters)
- [ ] Configure ALLOWED_ORIGINS for your iOS app
- [ ] Set NODE_ENV=production
- [ ] Enable SSL on database connection
- [ ] Set up database backups
- [ ] Configure monitoring/logging
- [ ] Set up rate limit alerts
- [ ] Review CORS settings
- [ ] Test all endpoints with Postman/curl

## License

MIT
