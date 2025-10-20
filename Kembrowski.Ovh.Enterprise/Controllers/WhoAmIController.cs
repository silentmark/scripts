using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Principal;
using System.Web.Http;

namespace Kembrowski.Ovh.Enterprise.Controllers
{
    public class WhoAmIController : ApiController
    {
        // GET api/whoami
        public IEnumerable<string> Get()
        {
            var identity = User?.Identity as WindowsIdentity;
            if (identity == null)
            {
                return new string[] { "Anonymous" };
            }

            var properties = new List<string>
            {
                $"Name: {identity.Name}",
                $"AuthenticationType: {identity.AuthenticationType}",
                $"IsAuthenticated: {identity.IsAuthenticated}",
                $"IsAnonymous: {identity.IsAnonymous}",
                $"IsGuest: {identity.IsGuest}",
                $"IsSystem: {identity.IsSystem}",
                $"ImpersonationLevel: {identity.ImpersonationLevel}",
                $"Token: {identity.Token}",
            };

            // Add claims if available
            var claimsIdentity = identity as System.Security.Claims.ClaimsIdentity;
            if (claimsIdentity != null && claimsIdentity.Claims.Any())
            {
                foreach (var claim in claimsIdentity.Claims)
                {
                    properties.Add($"Claim: Type={claim.Type}, Value={claim.Value}");
                }
            }

            return properties;
        }

        // GET api/whoami/name
        [Route("api/whoami/name")]
        public string GetName()
        {
            var identity = User?.Identity as WindowsIdentity;
            string username = identity?.Name;
            username = string.IsNullOrEmpty(username) ? "Anonymous" : username;
            return username;
        }

        // POST api/whoami
        public void Post([FromBody] string value)
        {
        }

        // PUT api/whoami/5
        public void Put(int id, [FromBody] string value)
        {
        }

        // DELETE api/whoami/5
        public void Delete(int id)
        {
        }
    }
}
