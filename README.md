# Delivery 1: Discovery & Reverse Engineering

## Proyecto Elegido

**Conduit** — [productionready-django-api](https://github.com/gothinkster/productionready-django-api)

Una implementación del spec [RealWorld](https://github.com/gothinkster/realworld-example-apps) usando **Django 1.10** y **Django REST Framework 3.4**. Es una API backend para una plataforma de blogging tipo Medium que incluye autenticación JWT, artículos, comentarios, tags, perfiles, follows y favoritos.

El proyecto se encuentra actualmente en un estado de **legacy degradado**, con dependencias fuera de soporte y prácticas de configuración inseguras, lo que impide su ejecución directa en entornos modernos y lo convierte en un candidato ideal para análisis de reverse engineering y modernización.


### ¿Por qué este proyecto?

- Es un proyecto real y completo con múltiples dominios de negocio (auth, artículos, perfiles, interacciones sociales).
- Tiene suficiente complejidad para aplicar Domain-Driven Design (5 bounded contexts identificados).
- Al estar desactualizado (Django 1.10, Python 3.5), ofrece oportunidades reales de análisis de fricción en el onboarding, documentadas en detalle en el Onboarding Log.
- Sigue el spec RealWorld, lo que permite validar las User Stories contra una especificación pública.

### Stack técnico

| Componente | Versión |
|---|---|
| Python | 3.5.2 |
| Django | 1.10.5 |
| Django REST Framework | 3.4.4 |
| PyJWT | 1.4.2 |
| Base de datos | SQLite3 |

---

## Entregables

| # | Entregable | Archivo |
|---|---|---|
| 1 | Context Map | [CONTEXT_MAP.md](./CONTEXT_MAP.md) |
| 2 | User Stories | [USER_STORIES.md](./USER_STORIES.md) |
| 3 | Onboarding Log | [ONBOARDING_LOG.md](./ONBOARDING_LOG.md) |

---

## Decisiones No-Triviales

### 1. Separación del Engagement como contexto cruzado

Al analizar el código, los favoritos y el feed personalizado no viven limpiamente en un solo módulo Django. Los favoritos están modelados en `profiles/models.py` (como M2M en `Profile`) pero expuestos vía `articles/views.py` (`ArticlesFavoriteAPIView`). Se decidió modelar **Engagement** como un contexto que cruza los bounded contexts de Content Management y Social Profile, en lugar de forzarlo dentro de uno solo. Esta decisión evita forzar un modelo artificial y refleja el acoplamiento real observado en la codebase legacy.


### 2. Shared Kernel para `conduit.apps.core`

El módulo `core` no representa un dominio de negocio sino infraestructura compartida (`TimestampedModel`, `ConduitJSONRenderer`, utilidades). Se clasificó como **Shared Kernel** en terminología DDD porque todos los demás contextos dependen de él vía herencia.

### 3. User Stories recuperadas del código, no inventadas

Las 20 User Stories fueron extraídas mediante ingeniería inversa del código fuente (views, serializers, models, URLs y signals), no de documentación externa. Cada US tiene trazabilidad directa a archivos específicos del repositorio.

### 4. Metodología AI-Native
El análisis completo fue realizado asistido por LLM (Claude, Anthropic). Se ingresaron los 46 archivos del repositorio como contexto y se aplicaron técnicas de análisis estático para identificar entidades de dominio, bounded contexts y user stories soportadas.

---

## Estructura del Repositorio Original

```
conduit/
├── apps/
│   ├── articles/          # Content Management + Engagement
│   │   ├── models.py      # Article, Comment, Tag
│   │   ├── views.py       # CRUD + Feed + Favorites
│   │   ├── serializers.py
│   │   ├── signals.py     # Auto-slug generation
│   │   ├── relations.py   # TagRelatedField
│   │   ├── renderers.py
│   │   └── urls.py
│   ├── authentication/    # Identity & Access Management
│   │   ├── models.py      # User (AbstractBaseUser)
│   │   ├── backends.py    # JWTAuthentication
│   │   ├── views.py       # Register, Login, Profile
│   │   ├── serializers.py
│   │   ├── signals.py     # Auto-create Profile on User save
│   │   ├── renderers.py
│   │   └── urls.py
│   ├── core/              # Shared Kernel
│   │   ├── models.py      # TimestampedModel
│   │   ├── renderers.py   # ConduitJSONRenderer
│   │   ├── exceptions.py  # Custom exception handler
│   │   └── utils.py       # Random string generator
│   └── profiles/          # Social Profile
│       ├── models.py      # Profile (follow, favorite)
│       ├── views.py       # Retrieve, Follow/Unfollow
│       ├── serializers.py
│       ├── renderers.py
│       └── urls.py
├── settings.py
├── urls.py
└── wsgi.py
```
