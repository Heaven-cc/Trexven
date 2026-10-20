// Uses a caller-scoped client: the RPC derives identity from auth.uid().
export async function assertStaffAccess(client: any, businessId: string, employeeId: string | null = null) {
  const { data, error } = await client.rpc('assert_trexven_staff_access', {
    p_business_id: businessId, p_employee_id: employeeId,
  });
  if (error || !data || data.owner !== true) {
    throw new Error('Staff administration denied');
  }
  return { owner: data.owner as boolean };
}
