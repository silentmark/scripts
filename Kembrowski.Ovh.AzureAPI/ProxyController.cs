using System.Web;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http.Extensions;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Identity.Abstractions;

[ApiController]
[Authorize]
public class ProxyController(IDownstreamApi downstreamApi) : ControllerBase
{
    private readonly IDownstreamApi _downstreamApi = downstreamApi;

    [HttpGet]
    [Route("api/whoami/name")]
    public async Task<IActionResult> Get()
    {
        var url = HttpUtility.UrlDecode(HttpContext.Request.GetEncodedUrl());
        var body = await _downstreamApi.GetForUserAsync<string>(
            "AppProxy",
            options => { options.RelativePath = "/api/whoami/name"; },
            user: HttpContext.User);

        return Ok(body);
    }

    [HttpPost]
    [Route("api/whoami")]
    public async Task<IActionResult> CallApi()
    {
        var body = await _downstreamApi.GetForUserAsync<string[]>(
            "AppProxy",
            options => { options.RelativePath = "/api/whoami"; },
            user: HttpContext.User);

        return Ok(body);
    }
}