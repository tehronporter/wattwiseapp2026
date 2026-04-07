const appDeepLinkBase = "wattwise://auth/callback";

function renderPage() {
  return `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Open WattWise</title>
    <style>
      :root {
        color-scheme: light;
        --bg: #f4f7fb;
        --card: rgba(255, 255, 255, 0.96);
        --text: #16324f;
        --muted: #5f7288;
        --line: rgba(22, 50, 79, 0.12);
        --accent: #1f78ff;
        --accent-dim: rgba(31, 120, 255, 0.12);
      }

      * {
        box-sizing: border-box;
      }

      body {
        margin: 0;
        min-height: 100vh;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        background:
          radial-gradient(circle at top, rgba(31, 120, 255, 0.14), transparent 36%),
          linear-gradient(180deg, #f8fbff 0%, var(--bg) 100%);
        color: var(--text);
        display: grid;
        place-items: center;
        padding: 24px;
      }

      .card {
        width: min(100%, 440px);
        background: var(--card);
        border: 1px solid var(--line);
        border-radius: 24px;
        padding: 28px;
        box-shadow: 0 24px 60px rgba(22, 50, 79, 0.12);
      }

      .badge {
        width: 64px;
        height: 64px;
        border-radius: 18px;
        background: var(--accent-dim);
        color: var(--accent);
        display: grid;
        place-items: center;
        font-size: 28px;
        margin-bottom: 20px;
      }

      h1 {
        margin: 0 0 12px;
        font-size: 30px;
        line-height: 1.1;
      }

      p {
        margin: 0 0 14px;
        color: var(--muted);
        line-height: 1.5;
      }

      .actions {
        display: flex;
        flex-direction: column;
        gap: 12px;
        margin-top: 24px;
      }

      .button {
        display: inline-flex;
        justify-content: center;
        align-items: center;
        min-height: 52px;
        padding: 0 18px;
        border-radius: 16px;
        text-decoration: none;
        font-weight: 600;
      }

      .button.primary {
        background: var(--accent);
        color: white;
      }

      .button.secondary {
        border: 1px solid var(--line);
        color: var(--text);
        background: white;
      }

      .footnote {
        margin-top: 18px;
        font-size: 14px;
      }
    </style>
  </head>
  <body>
    <main class="card">
      <div class="badge">⚡</div>
      <h1 id="title">Opening WattWise</h1>
      <p id="message">Hold on while we send you back into the app.</p>
      <p id="detail">If WattWise does not open automatically, use the button below.</p>
      <div class="actions">
        <a id="continue" class="button primary" href="${appDeepLinkBase}">Continue in WattWise</a>
        <a id="signin" class="button secondary" href="${appDeepLinkBase}?mode=signin">Open Sign-In</a>
      </div>
      <p class="footnote">If you confirmed on another device, open WattWise on your iPhone and sign in with the same email.</p>
    </main>
    <script>
      const title = document.getElementById("title");
      const message = document.getElementById("message");
      const detail = document.getElementById("detail");
      const continueButton = document.getElementById("continue");
      const signInButton = document.getElementById("signin");

      const hashParams = new URLSearchParams(window.location.hash.replace(/^#/, ""));
      const queryParams = new URLSearchParams(window.location.search);
      const combined = new URLSearchParams();

      queryParams.forEach((value, key) => combined.set(key, value));
      hashParams.forEach((value, key) => combined.set(key, value));

      const hasSession = combined.get("access_token") && combined.get("refresh_token");
      const hasError = combined.get("error") || combined.get("error_code") || combined.get("error_description");

      if (hasSession) {
        title.textContent = "Email confirmed";
        message.textContent = "Your account is ready. We are sending you back into WattWise now.";
        continueButton.href = \`${appDeepLinkBase}?\${combined.toString()}\`;
        signInButton.href = \`${appDeepLinkBase}?mode=signin\`;

        window.setTimeout(() => {
          window.location.replace(continueButton.href);
        }, 450);
      } else if (hasError) {
        title.textContent = "This link needs a fresh retry";
        message.textContent = combined.get("error_description") || "That confirmation link is no longer valid.";
        detail.textContent = "Return to WattWise and request a new confirmation email.";
        continueButton.textContent = "Open WattWise";
        continueButton.href = \`${appDeepLinkBase}?\${combined.toString()}\`;
        signInButton.href = \`${appDeepLinkBase}?mode=signin\`;
      } else {
        title.textContent = "Return to WattWise";
        message.textContent = "Your email was checked. Open WattWise on this device to finish signing in.";
        detail.textContent = "If you are on a laptop or another phone, go back to your iPhone and sign in there.";
      }
    </script>
  </body>
</html>`;
}

Deno.serve((req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "access-control-allow-origin": "*",
        "access-control-allow-methods": "GET, OPTIONS",
      },
    });
  }

  return new Response(renderPage(), {
    headers: {
      "content-type": "text/html; charset=utf-8",
      "cache-control": "no-store",
    },
  });
});
