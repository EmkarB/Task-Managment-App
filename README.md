# Task Yönetim Uygulaması

Task'lerini takip edebileceğin, birden fazla cihazda senkronize çalışan bi uygulama.

## Başlamadan önce

Bu projeyi Ubuntu üzerinde geliştirdim. Windows'ta Docker Desktop kullanırken bazı sıkıntılar çıkabiliyo, o yüzden WSL2 + Ubuntu kombosunu öneririm.

## Nasıl çalıştırıyosun?

```bash
docker-compose up --build
```

İlk seferde biraz beklersin, image'lar iniyo. Bittikten sonra:

- http://localhost → Arayüz
- http://localhost:8000/docs → API dokümantasyonu

## İlk kullanım

Hazır kullanıcı yok, kendin açıyosun:

1. http://localhost adresine git
2. "Register" kısmından yeni hesap aç (email + şifre, min 6 karakter)
3. Kayıt olduktan sonra aynı bilgilerle giriş yap
4. Task eklemeye başla

## Servisler

| Servis   | Port  | Ne yapıyo                       |
| -------- | ----- | ------------------------------- |
| frontend | 80    | React + Nginx, production build |
| backend  | 8000  | FastAPI, tüm API ve WebSocket   |
| postgres | 5432  | Kullanıcı verileri              |
| mongodb  | 27017 | Task verileri                   |
| redis    | 6379  | Cache                           |

## Redis neden ve nasıl kullanıldı

Her task listesi isteğinde MongoDB'ye gitmek yavaş. Redis ile cache yapıyorum:

1. `GET /tasks` geldiğinde önce Redis'e bakıyorum
2. Cache varsa direkt dönüyorum (HIT)
3. Yoksa MongoDB'den çekip Redis'e yazıyorum (MISS)

**Cache key formatı:** `tasks:user:{userId}` - her kullanıcının kendi cache'i var

**TTL:** 5 dakika (300 saniye)

**Invalidation:** Task eklendiğinde, güncellendiğinde veya silindiğinde o kullanıcının cache'i siliniyo. Böylece eski veri gösterilmiyo.

Response header'larında `X-Cache: HIT` veya `X-Cache: MISS` yazıyo, debug için kullanışlı.

## WebSocket neden ve nasıl kullanıldı

Birden fazla sekmede veya cihazda aynı hesapla açıksan, bi yerden task eklediğinde diğerlerinin de görmesi lazım. Sayfa yenilemeden.

**Nasıl çalışıyo:**

1. Frontend login olunca WebSocket bağlantısı kuruyo
2. Backend'de task oluşturulduğunda/güncellendiğinde/silindiğinde event yayınlanıyo
3. O kullanıcıya bağlı tüm client'lar bu event'i alıyo
4. Frontend event alınca task listesini yeniden çekiyo

**Event formatı:**

```json
{
  "type": "task.created",
  "taskId": "abc123",
  "timestamp": 1700000000
}
```

Event tipleri: `task.created`, `task.updated`, `task.deleted`

## API

### Auth (PostgreSQL)

- `POST /auth/register` - Kayıt
- `POST /auth/login` - Giriş, JWT token döner
- `GET /auth/me` - Profil bilgisi (token gerekli)

### Tasks (MongoDB, token gerekli)

- `GET /tasks` - Listele (cache'li)
- `POST /tasks` - Ekle
- `PATCH /tasks/:id` - Güncelle
- `DELETE /tasks/:id` - Sil

### Health

- `GET /health` - Sistem durumu

## Teknik kararlar

**Neden iki veritabanı?**
PostgreSQL kullanıcı verileri için - ilişkisel yapı, sabit şema. MongoDB task'ler için - daha esnek, şema değişebilir.

**Neden FastAPI?**
Async native olduğu için WebSocket ve yüksek performans için uygun. Otomatik Swagger dokümantasyonu da güzel.

**Neden Socket.IO?**
Plain WebSocket yerine Socket.IO kullandım çünkü reconnect, room desteği ve fallback mekanizması hazır geliyo.

**Neden Nginx?**
Frontend'i serve etmek için. Ayrıca production'da reverse proxy olarak da kullanılabilir.

## Klasör yapısı

```
├── docker-compose.yml
├── .env.example
├── packages/
│   ├── backend/
│   │   ├── app/
│   │   │   ├── main.py
│   │   │   ├── config.py
│   │   │   ├── database.py
│   │   │   ├── schemas.py
│   │   │   ├── models/
│   │   │   ├── routes/
│   │   │   └── services/
│   │   ├── requirements.txt
│   │   └── Dockerfile
│   └── frontend/
│       ├── src/
│       ├── nginx.conf
│       └── Dockerfile
```

## Ayarlar

`.env.example`'ı `.env` olarak kopyala:

```bash
cp .env.example .env
```

JWT_SECRET'ı production'da mutlaka değiştir.
