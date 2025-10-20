using Kembrowski.Ovh.Azure;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http.Extensions;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.Extensions.Options;
using Microsoft.Identity.Abstractions;
using Microsoft.Identity.Web;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;
using System.Web;

[Authorize]
public class IndexModel(IOptions<AppProxyOptions> options, IDownstreamApi downstreamApi) : PageModel
{
    public string? ApiResult { get; set; }
    public string? Error { get; set; }

    private readonly IDownstreamApi _downstreamApi = downstreamApi;
    private readonly string _scope = options.Value.Scopes;
    public async Task<IActionResult> OnGet()
    {
        var url = HttpUtility.UrlDecode(HttpContext.Request.GetEncodedUrl());
        try
        {
            // IDownstreamAPI automatycznie zajmie się pobraniem tokena i dołączeniem go do requestu
            var body = await _downstreamApi.GetForUserAsync<string>(
                "AppProxy",
                options =>
                {
                    // ten sam tenant, więc pobieramy z claimów - ale może być z konfiguracji
                    options.AcquireTokenOptions = new AcquireTokenOptions
                    {
                        Tenant = HttpContext.User.Claims.First(x => x.Type == "http://schemas.microsoft.com/identity/claims/tenantid").Value // optional but helps in multi-tenant scenarios
                    };
                    // Zakresy do pobrania tokena - z konfiguracji AppProxy
                    options.Scopes = [_scope];
                    // Ścieżka do API w App Proxy
                    options.RelativePath = "/api/whoami/name";
                }, user: HttpContext.User);

            ApiResult = body;
        }
        catch (MicrosoftIdentityWebChallengeUserException ex)
        {
            // W przypadku błędu 401 wymagana jest pobranie tokena/nadanie consent/zgód
            // Teoretycznie, ponieważ consent jest już nadany, a my podaliśmy login hint, nie powinno pojawić się kolejne okno logowania, 
            // ale może nastąpić przekierowanie, które po automatycznym uwierzytelnieniu, powróci do url (RedirectUri)
            var props = new AuthenticationProperties
            {
                RedirectUri = url,
                Items =
                {
                    { OpenIdConnectParameterNames.Scope, _scope },
                    { OpenIdConnectParameterNames.LoginHint,
                        HttpContext.User.Claims.FirstOrDefault(x => x.Type == "preferred_username")?.Value ?? HttpContext.User.Identity?.Name ?? "" },
                    { OpenIdConnectParameterNames.Username, HttpContext.User.Identity?.Name ?? "" }
                }
            };
            return Challenge(props, OpenIdConnectDefaults.AuthenticationScheme);
        }
        catch (Exception ex)
        {
            // Coś się jednak walnęło.
            Error = ex.ToString();
        }
        return Page();
    }

    public async Task<IActionResult> OnPostCallApi()
    {
        var body = await _downstreamApi.GetForUserAsync<string[]>(
                    "AppProxy",
                    options =>
                    {
                        options.AcquireTokenOptions = new AcquireTokenOptions
                        {
                            Tenant = HttpContext.User.Claims.First(x => x.Type == "http://schemas.microsoft.com/identity/claims/tenantid").Value // optional but helps in multi-tenant scenarios
                        };
                        options.Scopes = [_scope];
                        options.RelativePath = "/api/whoami";
                    }, user: HttpContext.User);

        ApiResult = string.Join(Environment.NewLine, body.Select(v => $"<value>{System.Security.SecurityElement.Escape(v)}</value>"));
        return Page();
    }

    public async Task<IActionResult> OnPostLogout()
    {
        await HttpContext.SignOutAsync();
        await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
        await HttpContext.SignOutAsync("OpenIdConnect");
        return RedirectToPage();
    }
}