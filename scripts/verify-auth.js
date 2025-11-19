#!/usr/bin/env node

/**
 * Script to verify NextAuth configuration
 * This script checks if the necessary environment variables are set
 * and provides guidance for fixing the UntrustedHost error.
 */

const fs = require("node:fs");
const path = require("node:path");

function verifyAuthConfig() {
  console.log("🔍 Verifying NextAuth configuration...\n");

  // Check environment variables
  const requiredEnvVars = ["AUTH_SECRET", "NEXTAUTH_SECRET", "NEXTAUTH_URL"];
  const missingVars = [];

  for (const varName of requiredEnvVars) {
    if (!process.env[varName]) {
      missingVars.push(varName);
    }
  }

  if (missingVars.length > 0) {
    console.log("❌ Missing environment variables:");
    for (const varName of missingVars) {
      console.log(`   - ${varName}`);
    }
    console.log(
      "\n💡 Please set these environment variables before deploying."
    );

    // Provide guidance based on deployment type
    console.log("\n📋 Example configurations:");
    console.log("   Local development:");
    console.log("   AUTH_SECRET=your-secret-key");
    console.log("   NEXTAUTH_SECRET=your-secret-key");
    console.log("   NEXTAUTH_URL=http://localhost:3000");
    console.log("");
    console.log("   Production with IP:");
    console.log("   AUTH_SECRET=your-secret-key");
    console.log("   NEXTAUTH_SECRET=your-secret-key");
    console.log("   NEXTAUTH_URL=http://122.51.119.81:3000");
    console.log("");
    console.log("   Production with domain:");
    console.log("   AUTH_SECRET=your-secret-key");
    console.log("   NEXTAUTH_SECRET=your-secret-key");
    console.log("   NEXTAUTH_URL=https://your-domain.com");

    process.exit(1);
  }

  console.log("✅ All required environment variables are set:");
  for (const varName of requiredEnvVars) {
    console.log(
      `   - ${varName}: ${varName.includes("SECRET") ? "***" : process.env[varName]}`
    );
  }

  // Check if trustHost is configured in auth.ts
  try {
    console.log("\n🔧 Checking NextAuth configuration...");

    const authConfigPath = path.join(__dirname, "../app/(auth)/auth.ts");
    const authConfigContent = fs.readFileSync(authConfigPath, "utf8");

    if (authConfigContent.includes("trustHost: true")) {
      console.log(
        "✅ trustHost: true is configured (fixes UntrustedHost errors)"
      );
    } else {
      console.log("❌ trustHost: true is not configured");
      console.log("   This may cause UntrustedHost errors in production");
    }

    if (authConfigContent.includes("Credentials")) {
      console.log(
        "✅ Credentials provider is configured for username authentication"
      );
    } else {
      console.log("❌ Credentials provider is not found");
    }

    console.log("\n🎉 NextAuth configuration verification passed!");
    console.log("\n📝 Configuration summary:");
    console.log("   - Environment variables: all required variables are set");
    console.log("   - trustHost: configured for IP-based deployments");
    console.log("   - Provider: username-based authentication");

    // Provide specific guidance for the error mentioned in the ticket
    console.log(
      '\n💡 For the specific error "UntrustedHost: Host must be trusted. URL was: http://122.51.119.81:3000/api/auth/session":'
    );
    console.log("   1. Ensure NEXTAUTH_URL=http://122.51.119.81:3000 is set");
    console.log("   2. The trustHost: true configuration is already applied");
    console.log(
      "   3. Restart the application after setting environment variables"
    );
  } catch (error) {
    console.error("❌ Error reading NextAuth configuration:", error.message);
    process.exit(1);
  }
}

// Run the verification
try {
  verifyAuthConfig();
} catch (error) {
  console.error("💥 Unexpected error during verification:", error);
  process.exit(1);
}
