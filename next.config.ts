import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  // Required for a minimal production image: server.js + traced dependencies.
  output: 'standalone',
};

export default nextConfig;
