FROM lukemathwalker/cargo-chef:latest-rust-1 AS chef

WORKDIR /app

RUN apt update && apt install lld clang -y

# Compute a lock-like file for our project
FROM chef as planner

COPY . .

RUN cargo chef prepare --recipe-path recipe.json

# Build our project dependencies, not our application
FROM chef as builder

COPY --from=planner /app/recipe.json recipe.json

RUN cargo chef cook --release --recipe-path recipe.json

COPY . .

# Build application
ENV SQLX_OFFLINE true

RUN cargo build --release --bin newsletter_mailer

# Runtime stage
FROM debian:bullseye-slim AS runtime

WORKDIR /app

RUN apt-get update -y \
    && apt-get install -y --no-install-recommends openssl ca-certificates \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/target/release/newsletter_mailer newsletter_mailer
COPY configuration configuration

ENV APP_ENVIRONMENT production

ENTRYPOINT ["./newsletter_mailer"]