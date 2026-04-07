import Foundation

enum IssuerDomainMap {
    static let domains: [String: String] = [
        // AI & ML
        "anthropic": "anthropic.com",
        "huggingface": "huggingface.co",
        "midjourney": "midjourney.com",
        "mistral": "mistral.ai",
        "openai": "openai.com",
        "stability ai": "stability.ai",

        // Cloud & hosting
        "amazon": "amazon.com",
        "aws": "aws.amazon.com",
        "cloudflare": "cloudflare.com",
        "digitalocean": "digitalocean.com",
        "fly.io": "fly.io",
        "heroku": "heroku.com",
        "hetzner": "hetzner.com",
        "linode": "linode.com",
        "netlify": "netlify.com",
        "ovh": "ovh.com",
        "railway": "railway.app",
        "render": "render.com",
        "scaleway": "scaleway.com",
        "supabase": "supabase.com",
        "upcloud": "upcloud.com",
        "vercel": "vercel.com",
        "vultr": "vultr.com",

        // Code & dev tools
        "atlassian": "atlassian.com",
        "bitbucket": "bitbucket.org",
        "buildkite": "buildkite.com",
        "circleci": "circleci.com",
        "datadog": "datadoghq.com",
        "docker": "docker.com",
        "github": "github.com",
        "gitlab": "gitlab.com",
        "hashicorp": "hashicorp.com",
        "jetbrains": "jetbrains.com",
        "npm": "npmjs.com",
        "packagist": "packagist.org",
        "planetscale": "planetscale.com",
        "pypi": "pypi.org",
        "rubygems.org": "rubygems.org",
        "sentry": "sentry.io",

        // Communication
        "discord": "discord.com",
        "element": "element.io",
        "signal": "signal.org",
        "slack": "slack.com",
        "telegram": "telegram.org",
        "zoom": "zoom.us",

        // Design
        "canva": "canva.com",
        "figma": "figma.com",
        "sketch": "sketch.com",

        // Domains & DNS
        "dnsimple": "dnsimple.com",
        "gandi": "gandi.net",
        "godaddy": "godaddy.com",
        "hover": "hover.com",
        "namecheap": "namecheap.com",
        "porkbun": "porkbun.com",
        "squarespace": "squarespace.com",

        // E-commerce
        "ebay": "ebay.com",
        "etsy": "etsy.com",
        "shopify": "shopify.com",

        // Email & productivity
        "airtable": "airtable.com",
        "asana": "asana.com",
        "clickup": "clickup.com",
        "evernote": "evernote.com",
        "fastmail": "fastmail.com",
        "google": "google.com",
        "mailchimp": "mailchimp.com",
        "microsoft": "microsoft.com",
        "miro": "miro.com",
        "monday.com": "monday.com",
        "notion": "notion.so",
        "proton": "proton.me",
        "protonmail": "protonmail.com",
        "todoist": "todoist.com",
        "tuta": "tuta.com",
        "zapier": "zapier.com",
        "zoho": "zoho.com",

        // Finance & crypto
        "binance": "binance.com",
        "cash app": "cash.app",
        "coinbase": "coinbase.com",
        "gemini": "gemini.com",
        "kraken": "kraken.com",
        "mercury": "mercury.com",
        "paypal": "paypal.com",
        "robinhood": "robinhood.com",
        "stripe": "stripe.com",
        "wise": "wise.com",

        // Gaming
        "battle.net": "battle.net",
        "electronic arts": "ea.com",
        "epic games": "epicgames.com",
        "gog.com": "gog.com",
        "nintendo": "accounts.nintendo.com",
        "riot games": "riotgames.com",
        "roblox": "roblox.com",
        "steam": "steampowered.com",
        "ubisoft": "ubisoft.com",

        // Password managers
        "1password": "1password.com",
        "bitwarden": "bitwarden.com",
        "dashlane": "dashlane.com",
        "keeper": "keepersecurity.com",
        "lastpass": "lastpass.com",

        // Social
        "facebook": "facebook.com",
        "instagram": "instagram.com",
        "linkedin": "linkedin.com",
        "pinterest": "pinterest.com",
        "reddit": "reddit.com",
        "snapchat": "snapchat.com",
        "tiktok": "tiktok.com",
        "tumblr": "tumblr.com",
        "twitter": "x.com",
        "x": "x.com",

        // Storage & file sharing
        "backblaze": "backblaze.com",
        "box": "box.com",
        "dropbox": "dropbox.com",
        "mega": "mega.io",
        "pcloud": "pcloud.com",

        // VPN & security
        "nordvpn": "nordvpn.com",
        "okta": "okta.com",
        "surfshark": "surfshark.com",
        "tunnelbear": "tunnelbear.com",

        // Other
        "adobe": "adobe.com",
        "gomashio industries": "opensesame.software",
        "apple": "apple.com",
        "docusign": "docusign.com",
        "ifttt": "ifttt.com",
        "kickstarter": "kickstarter.com",
        "patreon": "patreon.com",
        "samsung": "samsung.com",
        "twilio": "twilio.com",
        "twitch": "twitch.tv",
        "uber": "uber.com",
        "wordpress": "wordpress.com",
    ]

    static func domain(for issuer: String) -> String? {
        domains[issuer.lowercased()]
    }
}
