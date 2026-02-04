/**
 * Database Seed Script
 *
 * Run with: npm run db:seed
 *
 * Creates sample data for development/testing
 */

require('dotenv').config();
const bcrypt = require('bcryptjs');
const { pool } = require('../config/database');

const BCRYPT_ROUNDS = 12;

const seed = async () => {
  const client = await pool.connect();

  try {
    console.log('Starting database seed...');

    await client.query('BEGIN');

    // ===================
    // CREATE ADMIN USER
    // ===================
    const adminPassword = await bcrypt.hash('Admin123!', BCRYPT_ROUNDS);
    const adminResult = await client.query(`
      INSERT INTO users (email, password_hash, name, role, email_verified)
      VALUES ($1, $2, $3, $4, true)
      ON CONFLICT (email) DO UPDATE SET name = EXCLUDED.name
      RETURNING id
    `, ['admin@example.com', adminPassword, 'Admin User', 'admin']);
    const adminId = adminResult.rows[0].id;
    console.log('✓ Created admin user (admin@example.com / Admin123!)');

    // ===================
    // CREATE ORGANIZATION
    // ===================
    const orgResult = await client.query(`
      INSERT INTO organizations (name, slug, owner_id)
      VALUES ($1, $2, $3)
      ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name
      RETURNING id
    `, ['Demo Organization', 'demo-org', adminId]);
    const orgId = orgResult.rows[0].id;

    // Update admin with organization
    await client.query(`
      UPDATE users SET organization_id = $1 WHERE id = $2
    `, [orgId, adminId]);
    console.log('✓ Created organization');

    // ===================
    // CREATE SAMPLE USER
    // ===================
    const userPassword = await bcrypt.hash('User1234!', BCRYPT_ROUNDS);
    await client.query(`
      INSERT INTO users (email, password_hash, name, role, organization_id, email_verified)
      VALUES ($1, $2, $3, $4, $5, true)
      ON CONFLICT (email) DO UPDATE SET name = EXCLUDED.name
    `, ['user@example.com', userPassword, 'Test User', 'user', orgId]);
    console.log('✓ Created test user (user@example.com / User1234!)');

    // ===================
    // CREATE SAMPLE TEMPLATES
    // ===================

    // Safety Inspection Template
    const safetyFields = JSON.stringify([
      { id: 'date', type: 'date', label: 'Inspection Date', required: true, order: 1 },
      { id: 'location', type: 'text', label: 'Location/Area', required: true, order: 2 },
      { id: 'inspector', type: 'text', label: 'Inspector Name', required: true, order: 3 },
      { id: 'section1', type: 'section', label: 'General Safety', order: 4 },
      { id: 'ppe', type: 'yesNo', label: 'PPE properly worn?', required: true, order: 5 },
      { id: 'exits', type: 'yesNo', label: 'Emergency exits clear?', required: true, order: 6 },
      { id: 'extinguishers', type: 'yesNo', label: 'Fire extinguishers accessible?', required: true, order: 7 },
      { id: 'section2', type: 'section', label: 'Equipment', order: 8 },
      { id: 'equipment_condition', type: 'dropdown', label: 'Equipment Condition', required: true, order: 9, options: ['Excellent', 'Good', 'Fair', 'Poor', 'Critical'] },
      { id: 'maintenance_needed', type: 'checkbox', label: 'Maintenance Required', order: 10 },
      { id: 'section3', type: 'section', label: 'Documentation', order: 11 },
      { id: 'hazards', type: 'textarea', label: 'Hazards Identified', order: 12 },
      { id: 'photo', type: 'photo', label: 'Site Photo', order: 13 },
      { id: 'rating', type: 'rating', label: 'Overall Safety Rating', required: true, order: 14 },
      { id: 'signature', type: 'signature', label: 'Inspector Signature', required: true, order: 15 },
    ]);

    await client.query(`
      INSERT INTO form_templates (name, description, category, organization_id, created_by, fields, is_public)
      VALUES ($1, $2, $3, $4, $5, $6, true)
      ON CONFLICT DO NOTHING
    `, ['Safety Inspection', 'Workplace safety inspection checklist', 'Safety', orgId, adminId, safetyFields]);
    console.log('✓ Created Safety Inspection template');

    // Incident Report Template
    const incidentFields = JSON.stringify([
      { id: 'incident_date', type: 'date', label: 'Date of Incident', required: true, order: 1 },
      { id: 'incident_time', type: 'time', label: 'Time of Incident', required: true, order: 2 },
      { id: 'location', type: 'location', label: 'Location', required: true, order: 3 },
      { id: 'incident_type', type: 'dropdown', label: 'Type of Incident', required: true, order: 4, options: ['Injury', 'Near Miss', 'Property Damage', 'Environmental', 'Security', 'Other'] },
      { id: 'severity', type: 'dropdown', label: 'Severity', required: true, order: 5, options: ['Minor', 'Moderate', 'Major', 'Critical'] },
      { id: 'description', type: 'textarea', label: 'Description of Incident', required: true, order: 6 },
      { id: 'witnesses', type: 'textarea', label: 'Witness Names', order: 7 },
      { id: 'injury_occurred', type: 'yesNo', label: 'Did injury occur?', required: true, order: 8 },
      { id: 'injury_details', type: 'textarea', label: 'Injury Details', order: 9 },
      { id: 'medical_treatment', type: 'yesNo', label: 'Medical treatment required?', order: 10 },
      { id: 'immediate_actions', type: 'textarea', label: 'Immediate Actions Taken', required: true, order: 11 },
      { id: 'photos', type: 'photo', label: 'Photos', order: 12 },
      { id: 'reporter_name', type: 'text', label: 'Reporter Name', required: true, order: 13 },
      { id: 'reporter_phone', type: 'phone', label: 'Reporter Phone', required: true, order: 14 },
      { id: 'signature', type: 'signature', label: 'Reporter Signature', required: true, order: 15 },
    ]);

    await client.query(`
      INSERT INTO form_templates (name, description, category, organization_id, created_by, fields, is_public)
      VALUES ($1, $2, $3, $4, $5, $6, true)
      ON CONFLICT DO NOTHING
    `, ['Incident Report', 'Report workplace incidents and accidents', 'Safety', orgId, adminId, incidentFields]);
    console.log('✓ Created Incident Report template');

    // Work Order Template
    const workOrderFields = JSON.stringify([
      { id: 'wo_number', type: 'text', label: 'Work Order #', required: true, order: 1 },
      { id: 'date_requested', type: 'date', label: 'Date Requested', required: true, order: 2 },
      { id: 'priority', type: 'dropdown', label: 'Priority', required: true, order: 3, options: ['Low', 'Medium', 'High', 'Emergency'] },
      { id: 'work_type', type: 'dropdown', label: 'Type of Work', required: true, order: 4, options: ['Repair', 'Maintenance', 'Installation', 'Inspection', 'Other'] },
      { id: 'location', type: 'text', label: 'Location', required: true, order: 5 },
      { id: 'equipment_id', type: 'text', label: 'Equipment ID', order: 6 },
      { id: 'description', type: 'textarea', label: 'Work Description', required: true, order: 7 },
      { id: 'materials_needed', type: 'textarea', label: 'Materials Needed', order: 8 },
      { id: 'estimated_hours', type: 'number', label: 'Estimated Hours', order: 9 },
      { id: 'assigned_to', type: 'text', label: 'Assigned To', order: 10 },
      { id: 'requestor_name', type: 'text', label: 'Requestor Name', required: true, order: 11 },
      { id: 'requestor_email', type: 'email', label: 'Requestor Email', required: true, order: 12 },
      { id: 'signature', type: 'signature', label: 'Requestor Signature', required: true, order: 13 },
    ]);

    await client.query(`
      INSERT INTO form_templates (name, description, category, organization_id, created_by, fields, is_public)
      VALUES ($1, $2, $3, $4, $5, $6, true)
      ON CONFLICT DO NOTHING
    `, ['Work Order', 'Maintenance work order request', 'Maintenance', orgId, adminId, workOrderFields]);
    console.log('✓ Created Work Order template');

    // Visitor Sign-In Template
    const visitorFields = JSON.stringify([
      { id: 'date', type: 'date', label: 'Date', required: true, order: 1 },
      { id: 'time_in', type: 'time', label: 'Time In', required: true, order: 2 },
      { id: 'visitor_name', type: 'text', label: 'Visitor Name', required: true, order: 3 },
      { id: 'company', type: 'text', label: 'Company', required: true, order: 4 },
      { id: 'email', type: 'email', label: 'Email', order: 5 },
      { id: 'phone', type: 'phone', label: 'Phone', order: 6 },
      { id: 'visiting', type: 'text', label: 'Person Visiting', required: true, order: 7 },
      { id: 'purpose', type: 'dropdown', label: 'Purpose of Visit', required: true, order: 8, options: ['Meeting', 'Delivery', 'Interview', 'Contractor Work', 'Tour', 'Other'] },
      { id: 'badge_number', type: 'text', label: 'Badge Number', order: 9 },
      { id: 'vehicle', type: 'text', label: 'Vehicle License Plate', order: 10 },
      { id: 'photo', type: 'photo', label: 'Visitor Photo', order: 11 },
      { id: 'safety_briefing', type: 'checkbox', label: 'Received Safety Briefing', required: true, order: 12 },
      { id: 'signature', type: 'signature', label: 'Visitor Signature', required: true, order: 13 },
    ]);

    await client.query(`
      INSERT INTO form_templates (name, description, category, organization_id, created_by, fields, is_public)
      VALUES ($1, $2, $3, $4, $5, $6, true)
      ON CONFLICT DO NOTHING
    `, ['Visitor Sign-In', 'Visitor registration and safety acknowledgment', 'Administration', orgId, adminId, visitorFields]);
    console.log('✓ Created Visitor Sign-In template');

    // Quality Checklist Template
    const qualityFields = JSON.stringify([
      { id: 'date', type: 'date', label: 'Inspection Date', required: true, order: 1 },
      { id: 'product_name', type: 'text', label: 'Product/Part Name', required: true, order: 2 },
      { id: 'batch_number', type: 'text', label: 'Batch/Lot Number', required: true, order: 3 },
      { id: 'quantity_inspected', type: 'number', label: 'Quantity Inspected', required: true, order: 4 },
      { id: 'section1', type: 'section', label: 'Visual Inspection', order: 5 },
      { id: 'appearance', type: 'yesNo', label: 'Appearance acceptable?', required: true, order: 6 },
      { id: 'labeling', type: 'yesNo', label: 'Labeling correct?', required: true, order: 7 },
      { id: 'packaging', type: 'yesNo', label: 'Packaging intact?', required: true, order: 8 },
      { id: 'section2', type: 'section', label: 'Measurements', order: 9 },
      { id: 'dimensions', type: 'yesNo', label: 'Dimensions within spec?', required: true, order: 10 },
      { id: 'weight', type: 'yesNo', label: 'Weight within spec?', required: true, order: 11 },
      { id: 'section3', type: 'section', label: 'Results', order: 12 },
      { id: 'defects_found', type: 'number', label: 'Number of Defects', required: true, order: 13 },
      { id: 'defect_types', type: 'multiSelect', label: 'Defect Types', order: 14, options: ['Scratch', 'Dent', 'Discoloration', 'Missing Part', 'Wrong Dimension', 'Other'] },
      { id: 'notes', type: 'textarea', label: 'Notes', order: 15 },
      { id: 'result', type: 'dropdown', label: 'Final Result', required: true, order: 16, options: ['Pass', 'Fail', 'Conditional Pass'] },
      { id: 'photo', type: 'photo', label: 'Photo Evidence', order: 17 },
      { id: 'inspector', type: 'text', label: 'Inspector Name', required: true, order: 18 },
      { id: 'signature', type: 'signature', label: 'Inspector Signature', required: true, order: 19 },
    ]);

    await client.query(`
      INSERT INTO form_templates (name, description, category, organization_id, created_by, fields, is_public)
      VALUES ($1, $2, $3, $4, $5, $6, true)
      ON CONFLICT DO NOTHING
    `, ['Quality Checklist', 'Product quality inspection checklist', 'Quality', orgId, adminId, qualityFields]);
    console.log('✓ Created Quality Checklist template');

    await client.query('COMMIT');
    console.log('\n✅ Database seeded successfully!');
    console.log('\nTest Accounts:');
    console.log('  Admin: admin@example.com / Admin123!');
    console.log('  User:  user@example.com / User1234!');

  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Seed failed:', error.message);
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
};

seed().catch(console.error);
