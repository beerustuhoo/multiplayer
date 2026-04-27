FROM dart:stable AS build

RUN apt-get update && apt-get install -y libsqlite3-dev && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get
COPY . .
RUN dart compile exe bin/server.dart -o bin/server

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y libsqlite3-0 libsqlite3-dev ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=build /app/bin/server /app/bin/server

RUN mkdir -p /app/data

EXPOSE 3000

CMD ["/app/bin/server"]
