# MoonPay DevOps Challenge

A Next.js application displaying cryptocurrency prices, built with Prisma 7 and PostgreSQL.

## Tech Stack

- **Framework**: Next.js 16 (App Router, Turbopack)
- **Language**: TypeScript 5.9 (ESM)
- **Database**: PostgreSQL 17 with Prisma 7 + pg adapter
- **Styling**: Tailwind CSS 4 (CSS-first configuration)
- **Runtime**: Node.js 22 LTS
- **Package Manager**: pnpm

## Quick Start

### Prerequisites

- Node.js 22+ (`nvm use` or `mise install`)
- pnpm (`corepack enable pnpm`)
- Docker (for PostgreSQL)

### Setup

```bash
# Set up environment
cp .env.example .env

# Install dependencies (runs prisma generate automatically)
pnpm install

# Start PostgreSQL
docker compose up -d postgres

# Run migrations
pnpm db:migrate

# Start development server
pnpm dev
```

The app will be available at [http://localhost:3000](http://localhost:3000).

## Available Scripts

| Command | Description |
|---------|-------------|
| `pnpm dev` | Start development server with Turbopack |
| `pnpm build` | Build for production |
| `pnpm start` | Start production server |
| `pnpm db:migrate` | Run database migrations |
| `pnpm db:push` | Push schema changes (no migration) |
| `pnpm db:studio` | Open Prisma Studio GUI |

## Project Structure

```
├── app/                  # Next.js App Router
│   ├── layout.tsx        # Root layout with fonts
│   ├── page.tsx          # Home page with currency table
│   └── globals.css       # Tailwind @theme configuration
├── components/           # React components
│   ├── table.tsx         # Currency table (Server Component)
│   └── table-placeholder.tsx  # Loading skeleton
├── lib/
│   └── prisma.ts         # Prisma client with pg adapter
├── prisma/
│   ├── schema.prisma     # Database schema
│   ├── generated/        # Generated Prisma client (gitignored)
│   └── migrations/       # SQL migrations
├── prisma.config.ts      # Prisma configuration
├── docker-compose.yaml   # PostgreSQL + Next.js services
├── Dockerfile            # Multi-stage production image (Next.js standalone + Prisma)
├── docker/               # Container entrypoint (migrations, then `node server.js`)
├── kustomize/            # Kustomize: app (base + overlays) and argocd (base + overlays)
├── terraform/            # local-minikube: minikube, addons, optional Argo CD install
└── scripts/              # local-up.sh, local-down.sh
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `POSTGRES_PRISMA_URL` | PostgreSQL connection string |

Example: `postgres://postgres:postgres@localhost:5432/currencies?schema=public`

## Database

### Schema

```prisma
model currencies {
  id        Int      @id @default(autoincrement())
  name      String
  code      String   @unique
  icon      String
  price     Decimal  @db.Decimal(15, 5)
  createdAt DateTime @default(now())
}
```

### Prisma 7 with pg Adapter

This project uses Prisma 7's driver adapter architecture with `node-postgres` for connection pooling. The client is generated to `prisma/generated/` and configured in `prisma.config.ts`.

## Docker

```bash
# Start PostgreSQL only
docker compose up -d postgres

# Build and run the production image locally (expects Postgres on host or compose)
cp .env.example .env
export POSTGRES_PRISMA_URL="postgres://postgres:postgres@host.docker.internal:5432/currencies?schema=public"  # or from .env
docker build -t devops-challenge:local .
docker run --rm -e POSTGRES_PRISMA_URL="$POSTGRES_PRISMA_URL" -p 3000:3000 devops-challenge:local
```

## Kubernetes and GitOps

All manifests live under **`kustomize/`**.

**App stack** (`kustomize/app/`): the **base** includes in-cluster PostgreSQL, the Next.js app, a PodDisruptionBudget, and hardened pod defaults. The **local** overlay uses **NodePort 30080** and pulls the app as `docker.io/xoibsurferx/devops-challenge:latest` (Docker Hub; `imagePullPolicy: Always` in the overlay). The **production** overlay adds an HPA (assumes `metrics-server`) and pins the image to `…:main` (override with your CD process).

**Argo CD** (`kustomize/argocd/`): **base** has `AppProject` + `Application` (default app path is the production overlay). The **local** / **production** `argocd` overlays choose which app overlay to sync. Edit `kustomize/argocd/base/application.yaml` if the Git `repoURL` or `targetRevision` should differ, then `kubectl apply -k` the matching `kustomize/argocd/overlays/...`. With Argo running: `kubectl port-forward svc/argocd-server -n argocd 8888:443` and the initial `admin` password from `kubectl -n argocd get secret argocd-initial-admin-secret -o go-template='{{.data.password|base64decode}}'`. Private Git remotes [need credentials in Argo](https://argo-cd.readthedocs.io/en/stable/user-guide/private-repositories/).

**Secrets:** base app manifests include **placeholder** connection strings. For real production, use Sealed Secrets, External Secrets, or a secret manager, and **never** commit real credentials.

```bash
# Render (no cluster)
kubectl kustomize kustomize/app/overlays/local
kubectl kustomize kustomize/app/overlays/production
kubectl kustomize kustomize/argocd/overlays/local
kubectl kustomize kustomize/argocd/overlays/production
```

### Local cluster: Terraform + one-command up / down

- **`terraform/local-minikube`**: `null_resource` + `local-exec` to run `minikube start`, enable addons, optionally `kubectl apply` the upstream Argo CD install manifest. **Destroy** runs `minikube delete` for the profile.
- **Scripts** wrap `terraform init/apply/destroy` and `kubectl apply -k` for the app’s local overlay; the app image is pulled from Docker Hub by default (optional `--local-image` to build a tag in-repo for advanced use).

**Prerequisites:** [minikube](https://minikube.sigs.k8s.io/docs/start/), `kubectl`, [Terraform](https://www.terraform.io/) **≥ 1.3** (and Docker for the minikube driver you use, if applicable).

```bash
# Bring up cluster (terraform apply), build image on minikube, deploy app
make local-up
# or:  ./scripts/local-up.sh
#       TF_APPLY_AUTO=1 ./scripts/local-up.sh   # terraform apply -auto-approve

# Optional flags
#   ./scripts/local-up.sh --skip-terraform   # cluster already running
#   ./scripts/local-up.sh --local-image      # build/load an image in-repo (optional; default: Hub :latest)
#   ./scripts/local-up.sh --skip-kustomize

# Tear down (minikube delete via terraform)
make local-down
# or:  ./scripts/local-down.sh
#       ./scripts/local-down.sh -auto-approve
```

**Copy** `terraform/local-minikube/terraform.tfvars.example` to `terraform.tfvars` to tune memory, driver, or `install_argocd` (do not commit `terraform.tfvars`).

**After `make local-up`:** the app is exposed on NodePort `30080` (e.g. `http://$(minikube ip):30080`) and health is at `/api/health`. On **macOS with the Docker driver**, that URL often **hangs in the browser** (the node IP is not always reachable from the host). Use either:

- `minikube service nextjs -n devops-challenge --url` (prints a working URL, or add `--` to open a browser if supported), or
- `kubectl -n devops-challenge port-forward svc/nextjs 3000:80` and open `http://127.0.0.1:3000` (and `/api/health` there).
