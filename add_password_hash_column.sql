-- Migration: Add password_hash column to users table if it doesn't exist
-- This is a one-time migration for JWT authentication support

DO $$
BEGIN
    -- Check if password_hash column exists
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'users' 
        AND column_name = 'password_hash'
    ) THEN
        -- Add the column
        ALTER TABLE users 
        ADD COLUMN password_hash VARCHAR(255) NULL;
        
        -- Add comment
        COMMENT ON COLUMN users.password_hash IS 'Bcrypt hashed password for JWT authentication';
        
        RAISE NOTICE 'Added password_hash column to users table';
    ELSE
        RAISE NOTICE 'password_hash column already exists in users table';
    END IF;
END $$;
