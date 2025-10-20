using Kembrowski.Ovh.Azure;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.Identity.Web;
using Microsoft.Identity.Web.UI;
using System.Security.Claims;

var builder = WebApplication.CreateBuilder(args);

builder.Services
     // Uwierzytelnianie i autoryzacja OIDC / cookie based 
     .AddAuthentication(OpenIdConnectDefaults.AuthenticationScheme)
     // Integracja z Entra po Cloud App (ClientID, TenantID oraz Secret w appsettings.json AzureAD)
     .AddMicrosoftIdentityWebApp(options =>
     {
         var appProxy = new AppProxyOptions();

         builder.Configuration.Bind("AzureAd", options);
         builder.Configuration.GetSection("AppProxy").Bind(appProxy);
         // domyślny scope App Proxy: https://enterpriseservice-kembrowskiatos.msappproxy.net/user_impersonation - user_impersonation
         options.Scope.Add(appProxy.Scopes);
         // Dodanie login_hint do requestu proxy pasujący do aktualnie zalogowanego użytkownika
         options.Events.OnRedirectToIdentityProvider = ctx =>
         {
             var u = ctx.HttpContext.User;
             if (u?.Identity?.IsAuthenticated == true)
             {
                 var hint = u.FindFirst("preferred_username")?.Value
                            ?? u.FindFirst(ClaimTypes.Upn)?.Value
                            ?? u.Identity?.Name;
                 if (!string.IsNullOrEmpty(hint))
                 {
                     ctx.ProtocolMessage.LoginHint = hint;
                 }
             }
             return Task.CompletedTask;
         };
     })
     // żeby nie konfigurować ręcznie Uwierzytelniania SSO, używamy DownStreamAPI 
    .EnableTokenAcquisitionToCallDownstreamApi()
    // Konfiguracja DownstreamAPI - Scope oraz URL App Proxy
    .AddDownstreamApi("AppProxy", builder.Configuration.GetSection("AppProxy"))
    // In-memory token cache - lepiej użyć rozwiązań rozproszonych w produkcji, np redis.
    .AddInMemoryTokenCaches();

builder.Services.AddRazorPages().AddMicrosoftIdentityUI();

// Options + HTTP client
builder.Services.Configure<AppProxyOptions>(builder.Configuration.GetSection("AppProxy"));
var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();

app.UseRouting();

app.UseAuthentication();
app.UseAuthorization();

app.MapRazorPages().RequireAuthorization();

app.Run();