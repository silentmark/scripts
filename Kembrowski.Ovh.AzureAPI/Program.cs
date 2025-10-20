using Kembrowski.Ovh.AzureApi;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Identity.Web;
using Microsoft.OpenApi.Models;

var builder = WebApplication.CreateBuilder(args);

var appProxyOptions = new AppProxyOptions();
builder.Configuration.GetSection("AppProxy").Bind(appProxyOptions);
var msOptions = new MicrosoftIdentityOptions();
builder.Configuration.GetSection("AzureAd").Bind(msOptions);
builder.Services.AddSingleton(msOptions);
builder.Services.AddSingleton(appProxyOptions);

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddMicrosoftIdentityWebApi(
    microsoftOptions =>
        {
            // identyfikacja jest taka sama
            builder.Configuration.Bind("AzureAd", microsoftOptions);
            microsoftOptions.IncludeErrorDetails = true;
        }, 
    jwtOptions =>
        {
            // jak uwierzytelnienie
            builder.Configuration.GetSection("AzureAd").Bind(jwtOptions);
        })
    .EnableTokenAcquisitionToCallDownstreamApi(opt =>
        {
            // również pobieranie tokenu dla downstream API
            builder.Configuration.Bind("AzureAd", opt);
        })
    .AddDownstreamApi("AppProxy", options =>
        {
            // dane do donwstream api.
            options.BaseUrl = appProxyOptions.BaseUrl;
            options.Scopes = appProxyOptions.Scopes.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        })
    .AddInMemoryTokenCaches()
    .Services.AddCors(options =>
    {
        options.AddPolicy("SPFxPolicy", builder =>
        {
            builder.WithOrigins(
                "https://localhost:4321",
                "https://kembrowskiatos.sharepoint.com"
            )
            .AllowAnyMethod()
            .AllowAnyHeader();
        });
    });

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo { Title = "AppProxy API", Version = "v1" });

    var bearerScheme = new OpenApiSecurityScheme
    {
        Description = "JWT Authorization header using the Bearer scheme. Example: \"Bearer {token}\"",
        Name = "Authorization",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        Reference = new OpenApiReference { Type = ReferenceType.SecurityScheme, Id = "Bearer" }
    };

    c.AddSecurityDefinition("Bearer", bearerScheme);
    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        { bearerScheme, Array.Empty<string>() }
    });
});

builder.Services.AddControllers();

var app = builder.Build();
app.UseHttpsRedirection();
app.UseStaticFiles();

app.UseRouting();
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(c =>
    {
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "AppProxy API v1");
    });
}

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.UseCors("SPFxPolicy");

app.Run();
