import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "standalone",
  experimental: {
    ppr: true,
  },
  // Prevent server-only packages from being bundled into client code
  serverExternalPackages: [
    'postgres',
    'drizzle-orm/postgres-js',
  ],
  images: {
    remotePatterns: [
      {
        hostname: "avatar.vercel.sh",
      },
      {
        protocol: "https",
        //https://nextjs.org/docs/messages/next-image-unconfigured-host
        hostname: "*.public.blob.vercel-storage.com",
      },
    ],
  },
  // Prevent Node.js modules from being bundled into client code
  webpack: (config, { isServer }) => {
    if (!isServer) {
      // Add resolve aliases to prevent webpack from trying to resolve these modules
      config.resolve.alias = {
        ...config.resolve.alias,
        'postgres': false,
        'drizzle-orm/postgres-js': false,
      };
    }
    return config;
  },
  // 允许局域网访问开发服务器（开发环境）
  ...(process.env.NODE_ENV === "development" && {
    allowedDevOrigins: [
      // 允许所有局域网IP访问
      "172.16.0.0/12", // 172.16.0.0 - 172.31.255.255
      "192.168.0.0/16", // 192.168.0.0 - 192.168.255.255
      "10.0.0.0/8", // 10.0.0.0 - 10.255.255.255
    ],
  }),
};

export default nextConfig;
