# Imagem da aplicacao Web + API do ModaMax (build em duas etapas).
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY modamax.web.csproj .
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /app/publish --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish .
# A aplicacao roda sem privilegios de root (usuario "app" da imagem oficial).
# Ela so grava nas chaves de protecao de dados e nas fotos dos produtos.
RUN mkdir -p /app/App_Data /app/wwwroot/uploads/produtos \
    && chown -R $APP_UID /app/App_Data /app/wwwroot/uploads
USER $APP_UID
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080
ENTRYPOINT ["dotnet", "modamax.web.dll"]
