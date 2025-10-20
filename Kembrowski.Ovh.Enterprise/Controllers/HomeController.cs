using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Principal;
using System.Web;
using System.Web.Mvc;

namespace Kembrowski.Ovh.Enterprise.Controllers
{
    public class HomeController : Controller
    {
        public ActionResult Index()
        {
            // Get current Windows identity
            WindowsIdentity identity = User?.Identity as WindowsIdentity;
            string username = identity?.Name;
            username = string.IsNullOrEmpty(username) ? "Anonymous" : username;
            ViewData["Hello"] = $"Hello {username}";
            return View();
        }
    }
}
