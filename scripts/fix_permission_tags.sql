-- Fix malformed permission tags in the database
-- This script identifies and fixes permission tags with the pattern "sysconsole_read_*_read"

-- First, let's see what roles have malformed permissions
SELECT id, name, permissions 
FROM Roles 
WHERE permissions LIKE '%sysconsole_read_*_read%';

-- Update malformed permission tags
-- The pattern "sysconsole_read_*_read" should likely be removed as it's invalid
UPDATE Roles 
SET permissions = REPLACE(permissions, ' sysconsole_read_*_read', '')
WHERE permissions LIKE '%sysconsole_read_*_read%';

UPDATE Roles 
SET permissions = REPLACE(permissions, 'sysconsole_read_*_read ', '')
WHERE permissions LIKE '%sysconsole_read_*_read%';

UPDATE Roles 
SET permissions = REPLACE(permissions, 'sysconsole_read_*_read', '')
WHERE permissions LIKE '%sysconsole_read_*_read%';

-- Clean up any double spaces that might remain
UPDATE Roles 
SET permissions = REPLACE(permissions, '  ', ' ')
WHERE permissions LIKE '%  %';

-- Trim leading/trailing spaces
UPDATE Roles 
SET permissions = TRIM(permissions);

-- Verify the fix
SELECT id, name, permissions 
FROM Roles 
WHERE permissions LIKE '%sysconsole_read_*_read%';

-- Show updated roles
SELECT id, name, SUBSTRING(permissions, 1, 100) as permissions_preview
FROM Roles 
WHERE name IN ('system_admin', 'system_manager', 'system_read_only_admin', 'system_user_manager');