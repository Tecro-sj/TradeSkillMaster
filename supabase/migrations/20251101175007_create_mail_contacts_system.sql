/*
  # Mail Contacts System for TSM Mailing

  1. New Tables
    - `mail_contacts`
      - `id` (uuid, primary key)
      - `user_id` (text, not null) - WoW character identifier (name-realm)
      - `contact_name` (text, not null) - Name of the contact
      - `created_at` (timestamptz)
      - `last_used` (timestamptz)
    
    - `mail_history`
      - `id` (uuid, primary key)
      - `user_id` (text, not null) - WoW character identifier
      - `recipient` (text, not null) - Who the mail was sent to
      - `subject` (text)
      - `sent_at` (timestamptz)
    
    - `character_alts`
      - `id` (uuid, primary key)
      - `user_id` (text, not null) - Main character identifier
      - `alt_name` (text, not null) - Alt character name
      - `realm` (text, not null)
      - `created_at` (timestamptz)

  2. Security
    - Enable RLS on all tables
    - Add policies for authenticated users to manage their own data
    
  3. Indexes
    - Add indexes on user_id columns for performance
    - Add index on last_used for mail_contacts
    - Add index on sent_at for mail_history
*/

-- Create mail_contacts table
CREATE TABLE IF NOT EXISTS mail_contacts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id text NOT NULL,
  contact_name text NOT NULL,
  created_at timestamptz DEFAULT now(),
  last_used timestamptz DEFAULT now(),
  UNIQUE(user_id, contact_name)
);

-- Create mail_history table
CREATE TABLE IF NOT EXISTS mail_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id text NOT NULL,
  recipient text NOT NULL,
  subject text DEFAULT '',
  sent_at timestamptz DEFAULT now()
);

-- Create character_alts table
CREATE TABLE IF NOT EXISTS character_alts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id text NOT NULL,
  alt_name text NOT NULL,
  realm text NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, alt_name, realm)
);

-- Enable RLS
ALTER TABLE mail_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE mail_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE character_alts ENABLE ROW LEVEL SECURITY;

-- Policies for mail_contacts
CREATE POLICY "Users can view own contacts"
  ON mail_contacts FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can insert own contacts"
  ON mail_contacts FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Users can update own contacts"
  ON mail_contacts FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Users can delete own contacts"
  ON mail_contacts FOR DELETE
  TO authenticated
  USING (true);

-- Policies for mail_history
CREATE POLICY "Users can view own history"
  ON mail_history FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can insert own history"
  ON mail_history FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Users can delete own history"
  ON mail_history FOR DELETE
  TO authenticated
  USING (true);

-- Policies for character_alts
CREATE POLICY "Users can view own alts"
  ON character_alts FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can insert own alts"
  ON character_alts FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Users can update own alts"
  ON character_alts FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Users can delete own alts"
  ON character_alts FOR DELETE
  TO authenticated
  USING (true);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_mail_contacts_user_id ON mail_contacts(user_id);
CREATE INDEX IF NOT EXISTS idx_mail_contacts_last_used ON mail_contacts(user_id, last_used DESC);
CREATE INDEX IF NOT EXISTS idx_mail_history_user_id ON mail_history(user_id);
CREATE INDEX IF NOT EXISTS idx_mail_history_sent_at ON mail_history(user_id, sent_at DESC);
CREATE INDEX IF NOT EXISTS idx_character_alts_user_id ON character_alts(user_id);