/**
 * Database Migration Script
 *
 * Run with: npm run db:migrate
 *
 * Creates all tables for DigitalFormsApp
 */

require('dotenv').config();
const { pool } = require('../config/database');

const migrate = async () => {
  const client = await pool.connect();

  try {
    console.log('Starting database migration...');

    await client.query('BEGIN');

    // ===================
    // USERS TABLE
    // ===================
    await client.query(`
      CREATE TABLE IF NOT EXISTS users (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        email VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        name VARCHAR(255) NOT NULL,
        role VARCHAR(50) DEFAULT 'user',
        organization_id UUID,
        is_active BOOLEAN DEFAULT true,
        email_verified BOOLEAN DEFAULT false,
        last_login_at TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    console.log('✓ Created users table');

    // ===================
    // ORGANIZATIONS TABLE
    // ===================
    await client.query(`
      CREATE TABLE IF NOT EXISTS organizations (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name VARCHAR(255) NOT NULL,
        slug VARCHAR(255) UNIQUE NOT NULL,
        owner_id UUID REFERENCES users(id),
        settings JSONB DEFAULT '{}',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    console.log('✓ Created organizations table');

    // Add foreign key to users after organizations exists
    await client.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM information_schema.table_constraints
          WHERE constraint_name = 'users_organization_id_fkey'
        ) THEN
          ALTER TABLE users
          ADD CONSTRAINT users_organization_id_fkey
          FOREIGN KEY (organization_id) REFERENCES organizations(id);
        END IF;
      END $$;
    `);

    // ===================
    // REFRESH TOKENS TABLE (for secure token rotation)
    // ===================
    await client.query(`
      CREATE TABLE IF NOT EXISTS refresh_tokens (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        token_hash VARCHAR(255) NOT NULL,
        expires_at TIMESTAMP NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        revoked_at TIMESTAMP
      )
    `);
    console.log('✓ Created refresh_tokens table');

    // ===================
    // FORM TEMPLATES TABLE
    // ===================
    await client.query(`
      CREATE TABLE IF NOT EXISTS form_templates (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name VARCHAR(255) NOT NULL,
        description TEXT,
        category VARCHAR(100),
        organization_id UUID REFERENCES organizations(id),
        created_by UUID REFERENCES users(id),
        fields JSONB NOT NULL DEFAULT '[]',
        settings JSONB DEFAULT '{}',
        is_active BOOLEAN DEFAULT true,
        is_public BOOLEAN DEFAULT false,
        version INTEGER DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    console.log('✓ Created form_templates table');

    // ===================
    // FORMS TABLE
    // ===================
    await client.query(`
      CREATE TABLE IF NOT EXISTS forms (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        template_id UUID REFERENCES form_templates(id),
        title VARCHAR(255) NOT NULL,
        status VARCHAR(50) DEFAULT 'draft',
        organization_id UUID REFERENCES organizations(id),
        created_by UUID REFERENCES users(id),
        assigned_to UUID REFERENCES users(id),
        fields JSONB NOT NULL DEFAULT '[]',
        metadata JSONB DEFAULT '{}',
        latitude DECIMAL(10, 8),
        longitude DECIMAL(11, 8),
        submitted_at TIMESTAMP,
        due_date TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    console.log('✓ Created forms table');

    // ===================
    // FORM SIGNATURES TABLE (Canadian legal compliance)
    // ===================
    await client.query(`
      CREATE TABLE IF NOT EXISTS form_signatures (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        form_id UUID NOT NULL REFERENCES forms(id) ON DELETE CASCADE,
        user_id UUID REFERENCES users(id),
        signer_name VARCHAR(255) NOT NULL,
        signer_email VARCHAR(255),
        signer_role VARCHAR(100),
        signature_type VARCHAR(50) DEFAULT 'drawn',
        signature_data TEXT,
        signature_url VARCHAR(500),
        ip_address VARCHAR(45),
        user_agent TEXT,
        device_id VARCHAR(255),
        latitude DECIMAL(10, 8),
        longitude DECIMAL(11, 8),
        signed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        witness_name VARCHAR(255),
        witness_email VARCHAR(255),
        -- Legal compliance fields (PIPEDA / Provincial ETAs)
        document_hash VARCHAR(64) NOT NULL,
        consent_given BOOLEAN NOT NULL DEFAULT true,
        consent_text TEXT NOT NULL
      )
    `);
    console.log('✓ Created form_signatures table (with legal compliance fields)');

    // ===================
    // FORM ATTACHMENTS TABLE
    // ===================
    await client.query(`
      CREATE TABLE IF NOT EXISTS form_attachments (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        form_id UUID NOT NULL REFERENCES forms(id) ON DELETE CASCADE,
        field_id VARCHAR(255),
        file_name VARCHAR(255) NOT NULL,
        file_type VARCHAR(100),
        file_size INTEGER,
        file_url VARCHAR(500) NOT NULL,
        thumbnail_url VARCHAR(500),
        caption TEXT,
        latitude DECIMAL(10, 8),
        longitude DECIMAL(11, 8),
        uploaded_by UUID REFERENCES users(id),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    console.log('✓ Created form_attachments table');

    // ===================
    // FORM APPROVALS TABLE
    // ===================
    await client.query(`
      CREATE TABLE IF NOT EXISTS form_approvals (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        form_id UUID NOT NULL REFERENCES forms(id) ON DELETE CASCADE,
        user_id UUID NOT NULL REFERENCES users(id),
        decision VARCHAR(50) NOT NULL,
        comments TEXT,
        decided_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    console.log('✓ Created form_approvals table');

    // ===================
    // FORM SHARES TABLE (for sharing forms with others)
    // ===================
    await client.query(`
      CREATE TABLE IF NOT EXISTS form_shares (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        form_id UUID NOT NULL REFERENCES forms(id) ON DELETE CASCADE,
        shared_by UUID NOT NULL REFERENCES users(id),
        shared_with_email VARCHAR(255) NOT NULL,
        shared_with_user UUID REFERENCES users(id),
        permission VARCHAR(50) DEFAULT 'sign',
        token VARCHAR(255) UNIQUE,
        expires_at TIMESTAMP,
        accessed_at TIMESTAMP,
        completed_at TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    console.log('✓ Created form_shares table');

    // ===================
    // WORKFLOW RULES TABLE
    // ===================
    await client.query(`
      CREATE TABLE IF NOT EXISTS workflow_rules (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name VARCHAR(255) NOT NULL,
        organization_id UUID REFERENCES organizations(id),
        template_id UUID REFERENCES form_templates(id),
        trigger_event VARCHAR(100) NOT NULL,
        conditions JSONB DEFAULT '[]',
        actions JSONB NOT NULL DEFAULT '[]',
        is_active BOOLEAN DEFAULT true,
        created_by UUID REFERENCES users(id),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    console.log('✓ Created workflow_rules table');

    // ===================
    // AUDIT LOG TABLE
    // ===================
    await client.query(`
      CREATE TABLE IF NOT EXISTS audit_logs (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID REFERENCES users(id),
        action VARCHAR(100) NOT NULL,
        resource_type VARCHAR(100) NOT NULL,
        resource_id UUID,
        old_values JSONB,
        new_values JSONB,
        ip_address VARCHAR(45),
        user_agent TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    console.log('✓ Created audit_logs table');

    // ===================
    // NOTIFICATIONS TABLE
    // ===================
    await client.query(`
      CREATE TABLE IF NOT EXISTS notifications (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        type VARCHAR(100) NOT NULL,
        title VARCHAR(255) NOT NULL,
        message TEXT,
        data JSONB DEFAULT '{}',
        read_at TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    console.log('✓ Created notifications table');

    // ===================
    // INDEXES
    // ===================
    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
      CREATE INDEX IF NOT EXISTS idx_users_organization ON users(organization_id);
      CREATE INDEX IF NOT EXISTS idx_forms_status ON forms(status);
      CREATE INDEX IF NOT EXISTS idx_forms_created_by ON forms(created_by);
      CREATE INDEX IF NOT EXISTS idx_forms_assigned_to ON forms(assigned_to);
      CREATE INDEX IF NOT EXISTS idx_forms_organization ON forms(organization_id);
      CREATE INDEX IF NOT EXISTS idx_form_signatures_form ON form_signatures(form_id);
      CREATE INDEX IF NOT EXISTS idx_form_attachments_form ON form_attachments(form_id);
      CREATE INDEX IF NOT EXISTS idx_form_shares_token ON form_shares(token);
      CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON audit_logs(user_id);
      CREATE INDEX IF NOT EXISTS idx_audit_logs_resource ON audit_logs(resource_type, resource_id);
      CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id);
      CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user ON refresh_tokens(user_id);
    `);
    console.log('✓ Created indexes');

    await client.query('COMMIT');
    console.log('\n✅ Migration completed successfully!');

  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Migration failed:', error.message);
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
};

migrate().catch(console.error);
