REPO PRONTO PARA GERAR APK VIA GITHUB ACTIONS
================================================

Como usar:
1) Faça upload desta pasta inteira para um repositório no GitHub (ou `git init` e dê push).
2) Vá na aba **Actions** do GitHub e rode o workflow **Build Android APK** (Run workflow).
3) Ao finalizar, baixe os artefatos:
   - app-debug.apk (assinado com debug; dá para instalar)
   - app-release.apk (unsigned; precisa assinar se for publicar)
   
Observações:
- O workflow cria a pasta `android/` automaticamente caso não exista (`flutter create .`).
- O projeto já contém `lib/` e `pubspec.yaml` com o app de vendas (PDF, CSV, ticket médio, lucro).
- Se quiser publicar na Play Store, posso adicionar assinatura com keystore segura (secrets).
