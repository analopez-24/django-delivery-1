# Delivery 1 & 2: Discovery, Reverse Engineering & Governance

## Proyecto Elegido

**Conduit** — [productionready-django-api](https://github.com/gothinkster/productionready-django-api)

Una implementación del spec [RealWorld](https://github.com/gothinkster/realworld-example-apps) usando **Django 1.10** y **Django REST Framework 3.4**. Es una API backend para una plataforma de blogging tipo Medium que incluye autenticación JWT, artículos, comentarios, tags, perfiles, follows y favoritos.

El proyecto se encuentra actualmente en un estado de **legacy degradado**, con dependencias fuera de soporte y prácticas de configuración inseguras, lo que impide su ejecución directa en entornos modernos y lo convierte en un candidato ideal para análisis de reverse engineering y modernización.

### ¿Por qué este proyecto?

- Es un proyecto real y completo con múltiples dominios de negocio (auth, artículos, perfiles, interacciones sociales).
- Tiene suficiente complejidad para aplicar Domain-Driven Design (5 bounded contexts identificados).
- Al estar desactualizado (Django 1.10, Python 3.5), ofrece oportunidades reales de análisis de fricción en el onboarding, documentadas en detalle en el Onboarding Log.
- Sigue el spec RealWorld, lo que permite validar las User Stories contra una especificación pública.
- Hemos trabajado con Django en proyectos personales y familiares, lo que nos da familiaridad con el framework.

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

### Delivery 1: Discovery & Reverse Engineering (Semana 2)

| # | Entregable | Archivo |
|---|---|---|
| 1 | Context Map | [CONTEXT_MAP.md](./CONTEXT_MAP.md) |
| 2 | User Stories | [USER_STORIES.md](./USER_STORIES.md) |
| 3 | Onboarding Log | [ONBOARDING_LOG.md](./ONBOARDING_LOG.md) |
| 4 | Documentación LLM | [DOCUMENTACION.md](./DOCUMENTACION.md) |

### Delivery 2: Governance & Technical Debt Audit (Semana 4)

| # | Entregable | Archivo |
|---|---|---|
| 1 | CI Pipeline (GitHub Actions) | [.github/workflows/ci.yml](./.github/workflows/ci.yml) |
| 2 | Configuración SonarQube | [sonar-project.properties](./sonar-project.properties) |
| 3 | Governance (CI + DORA + Quality Gates) | [GOVERNANCE.md](./GOVERNANCE.md) |
| 4 | Tech Debt Audit + Refactoring Plan | [TECH_DEBT_AUDIT.md](./TECH_DEBT_AUDIT.md) |

---

## Decisiones No-Triviales

### Delivery 1

#### 1. Separación del Engagement como contexto cruzado

Al analizar el código, los favoritos y el feed personalizado no viven limpiamente en un solo módulo Django. Los favoritos están modelados en `profiles/models.py` (como M2M en `Profile`) pero expuestos vía `articles/views.py` (`ArticlesFavoriteAPIView`). Decidimos modelar **Engagement** como un contexto que cruza los bounded contexts de Content Management y Social Profile, en lugar de forzarlo dentro de uno solo. Esta decisión evita forzar un modelo artificial y refleja el acoplamiento real observado en la codebase legacy.

#### 2. Shared Kernel para `conduit.apps.core`

El módulo `core` no representa un dominio de negocio sino infraestructura compartida (`TimestampedModel`, `ConduitJSONRenderer`, utilidades). Lo clasificamos como **Shared Kernel** en terminología DDD porque todos los demás contextos dependen de él vía herencia.

#### 3. User Stories recuperadas del código, no inventadas

Las 20 User Stories fueron extraídas mediante ingeniería inversa del código fuente (views, serializers, models, URLs y signals), no de documentación externa. Cada US tiene trazabilidad directa a archivos específicos del repositorio.

### Delivery 2

#### 4. Python 3.10 en el CI en lugar de 3.5

El proyecto original requiere Python 3.5.2, pero esta versión es imposible de instalar en runners modernos de GitHub Actions. Configuramos el pipeline con **Python 3.10** como versión objetivo post-migración. Las herramientas de análisis estático (radon, xenon, flake8) funcionan correctamente sobre el código sin necesidad de ejecutarlo.

#### 5. Strangler Fig por bounded context, no por capa

Al diseñar el plan de refactoring, decidimos organizar los pasos por **bounded context** (separar vistas de Engagement de Content Management) en lugar de por capa técnica (mover todos los serializers, luego todos los views, etc.). Esto se alinea con DDD y reduce el riesgo de romper funcionalidades completas durante la migración.

#### 6. Tests como Fase 0 obligatoria

No existe ningún test en el proyecto. Antes de iniciar cualquier refactoring del Strangler Fig, definimos una **Fase 0 de cobertura mínima** como prerrequisito. Refactorizar sin tests sería equivalente a caminar a ciegas.

### Metodología

#### 7. Metodología AI-Native

El análisis completo fue realizado asistido por LLM (Claude, Anthropic). Se ingresaron los 46 archivos del repositorio como contexto y se aplicaron técnicas de análisis estático para identificar entidades de dominio, bounded contexts, user stories soportadas, hotspots y deuda técnica.

---

## Estructura del Repositorio Original

```
conduit/
├── apps/
│   ├── articles/          # Content Management + Engagement
│   │   ├── models.py      # Article, Comment, Tag
│   │   ├── views.py       # CRUD + Feed + Favorites  ← HOTSPOT #1
│   │   ├── serializers.py
│   │   ├── signals.py     # Auto-slug generation
│   │   ├── relations.py   # TagRelatedField
│   │   ├── renderers.py
│   │   └── urls.py
│   ├── authentication/    # Identity & Access Management
│   │   ├── models.py      # User (AbstractBaseUser)   ← HOTSPOT #2
│   │   ├── backends.py    # JWTAuthentication
│   │   ├── views.py       # Register, Login, Profile
│   │   ├── serializers.py #                            ← HOTSPOT #3
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
