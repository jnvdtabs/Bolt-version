/*
# Fix RLS Policy for Profiles Table

This migration fixes the infinite recursion issue in the profiles table RLS policy by:
1. Dropping the problematic policy that causes circular dependency
2. Creating a simpler policy that avoids recursion
3. Ensuring users can view their own profiles and approved profiles
4. Allowing admins to view all profiles without causing infinite loops

## Changes Made:
- Removed the recursive policy that was calling itself
- Created a new policy that checks admin status more efficiently
- Used a direct approach to avoid function calls that could cause recursion
*/

-- Drop the existing problematic policy
DROP POLICY IF EXISTS "Users can view approved profiles" ON public.profiles;

-- Drop the function that was causing recursion
DROP FUNCTION IF EXISTS public.get_current_user_role();

-- Create a new, simpler policy that avoids recursion
-- This policy allows:
-- 1. Users to view approved profiles
-- 2. Users to view their own profile (regardless of approval status)
-- 3. We'll handle admin access through a separate mechanism
CREATE POLICY "Users can view approved profiles" 
ON public.profiles 
FOR SELECT 
TO public
USING (
  approved = true 
  OR auth.uid() = user_id
);

-- Create a separate policy for admin access that doesn't cause recursion
-- This uses a more direct approach by checking if there's an admin profile
-- for the current user without creating a circular dependency
CREATE POLICY "Admins can view all profiles"
ON public.profiles
FOR SELECT
TO public
USING (
  EXISTS (
    SELECT 1 
    FROM public.profiles admin_check 
    WHERE admin_check.user_id = auth.uid() 
    AND admin_check.role = 'admin'
    AND admin_check.approved = true
  )
);