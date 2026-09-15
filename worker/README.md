# Proxy Gemini per CPRedux

Il Worker riceve `{ "prompt": "..." }` e inoltra la richiesta a Gemini. La
chiave resta nel secret `GEMINI_API_KEY` di Cloudflare: non viene mai inserita
nell'applicazione Flutter, nel repository o nell'installer.

## Primo collegamento (una sola volta)

1. Crea un account gratuito su Cloudflare.
2. Crea un API token Cloudflare con permesso **Workers Scripts: Edit** e annota
   anche l'Account ID.
3. Aggiungi questi secret al repository GitHub:
   - `CLOUDFLARE_API_TOKEN`
   - `CLOUDFLARE_ACCOUNT_ID`
   - `GEMINI_API_KEY`
4. Avvia il workflow **Deploy Gemini proxy**. Il workflow pubblica il Worker e
   aggiorna il secret Gemini senza stampare il valore nei log.
5. Copia l'URL `https://cpredux-gemini-proxy.<tuo-account>.workers.dev` e
   aggiungilo ai secret GitHub come `GEMINI_PROXY_URL`.

Da quel momento le release desktop usano il proxy. La chiave Gemini non viene
più passata a `flutter build`.

Il Worker limita già ogni IP a 20 richieste al minuto e rifiuta prompt oltre
8000 caratteri. Prima di distribuirlo a un pubblico molto grande conviene
aggiungere anche una regola di rate limiting nel pannello Cloudflare: un URL
pubblico può essere chiamato da chiunque lo scopra.

Per sviluppo locale puoi pubblicare manualmente con:

```bash
npx wrangler secret put GEMINI_API_KEY --config worker/wrangler.toml
npx wrangler deploy --config worker/wrangler.toml
```
