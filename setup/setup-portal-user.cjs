// Setup script: Associate contact with web role and create portal invitation
// Uses device code flow to authenticate to GCC Dataverse

const https = require('https');
const readline = require('readline');

const TENANT_ID = '2fb265c3-c7b6-40d4-9db0-9fc61b89354a';
const CLIENT_ID = '04b07795-8ddb-461a-bbee-02f9e1bf7b46'; // Azure CLI public client (universal)
const RESOURCE = 'https://orga381269e.crm9.dynamics.com';
const ENV_URL = 'https://orga381269e.crm9.dynamics.com';
const AUTH_URL = `https://login.microsoftonline.com/${TENANT_ID}/oauth2`; // Commercial auth endpoint

const CONTACT_ID = 'd2c23913-f238-f111-88b3-001dd801f94a';
const WEBROLE_ID = 'c7500f9c-350c-471b-a6da-e16f0f18009c'; // Authenticated Users
const WEBSITE_ID = '461a50ae-9496-419e-a58b-14d56165b009';

function httpRequest(url, options, body) {
  return new Promise((resolve, reject) => {
    const parsedUrl = new URL(url);
    const req = https.request({
      hostname: parsedUrl.hostname,
      path: parsedUrl.pathname + parsedUrl.search,
      method: options.method || 'GET',
      headers: options.headers || {},
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body: data }));
    });
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

async function getToken() {
  // Start device code flow (v1.0 endpoint for GCC)
  const codeResp = await httpRequest(`${AUTH_URL}/devicecode`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
  }, `client_id=${CLIENT_ID}&resource=${encodeURIComponent(RESOURCE)}`);
  
  const codeData = JSON.parse(codeResp.body);
  if (codeData.error) throw new Error(codeData.error_description || codeData.error);
  console.log('\n' + codeData.message + '\n');
  
  // Poll for token
  const interval = codeData.interval || 5;
  while (true) {
    await new Promise(r => setTimeout(r, interval * 1000));
    const tokenResp = await httpRequest(`${AUTH_URL}/token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
    }, `client_id=${CLIENT_ID}&grant_type=urn:ietf:params:oauth:grant-type:device_code&code=${codeData.device_code}`);
    
    const tokenData = JSON.parse(tokenResp.body);
    if (tokenData.access_token) return tokenData.access_token;
    if (tokenData.error === 'authorization_pending') continue;
    throw new Error(tokenData.error_description || tokenData.error);
  }
}

async function apiCall(token, method, path, body) {
  const headers = {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json',
    'OData-MaxVersion': '4.0',
    'OData-Version': '4.0',
    'Accept': 'application/json',
    'Prefer': 'return=representation',
  };
  const resp = await httpRequest(`${ENV_URL}${path}`, { method, headers }, body ? JSON.stringify(body) : undefined);
  return resp;
}

async function main() {
  console.log('=== Contoso DMV Portal User Setup ===');
  console.log('Authenticating to GCC Dataverse...\n');
  
  const token = await getToken();
  console.log('Authenticated successfully!\n');

  // Step 1: Associate contact with "Authenticated Users" web role
  console.log('1. Associating Maria Jennings with "Authenticated Users" web role...');
  const assocResp = await apiCall(token, 'POST',
    `/api/data/v9.2/contacts(${CONTACT_ID})/mspp_webrole_contact/$ref`,
    { '@odata.id': `${ENV_URL}/api/data/v9.2/mspp_webroles(${WEBROLE_ID})` }
  );
  if (assocResp.status === 204 || assocResp.status === 200) {
    console.log('   ✅ Web role assigned successfully');
  } else {
    console.log(`   ⚠️ Response: ${assocResp.status} - ${assocResp.body}`);
  }

  // Step 2: Create portal invitation for the contact
  console.log('\n2. Creating portal invitation...');
  const inviteResp = await apiCall(token, 'POST', '/api/data/v9.2/adx_invitations', {
    'adx_name': 'Maria Jennings - Citizen Portal Access',
    'adx_type': 756150000, // Single
    'mspp_websiteid@odata.bind': `/mspp_websites(${WEBSITE_ID})`,
    'adx_inviteContact@odata.bind': `/contacts(${CONTACT_ID})`,
  });
  
  if (inviteResp.status === 201 || inviteResp.status === 200) {
    const invite = JSON.parse(inviteResp.body);
    console.log('   ✅ Invitation created');
    console.log(`   Invitation Code: ${invite.adx_invitationcode || 'N/A'}`);
  } else {
    console.log(`   ⚠️ Invitation response: ${inviteResp.status}`);
    console.log(`   ${inviteResp.body.substring(0, 500)}`);
    console.log('\n   Note: Invitations may not be available for code sites.');
    console.log('   The contact can register directly via the portal sign-up page.');
  }

  console.log('\n=== Setup Complete ===');
  console.log(`\nContact: Maria Jennings`);
  console.log(`Email: kellycason+maria@microsoft.com`);
  console.log(`Web Role: Authenticated Users`);
  console.log(`\nNext steps:`);
  console.log(`  1. Navigate to your Power Pages site URL`);
  console.log(`  2. Click "Sign In" or "Register"`);
  console.log(`  3. Register with email: kellycason+maria@microsoft.com`);
  console.log(`  4. The portal will match this to the contact record automatically`);
  console.log(`  5. After email confirmation, Maria can log in as a citizen`);
}

main().catch(err => {
  console.error('Error:', err.message);
  process.exit(1);
});
