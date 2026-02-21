# Tech Debt Audit

## 1. Metodologia de Identificacion de Hotspots

Para identificar los hotspots del proyecto, combinamos dos dimensiones de analisis:

- **Complejidad ciclomatica:** Medida con `radon`, indica que tan dificil es entender, testear y modificar un archivo.
- **Churn potencial (acoplamiento + responsabilidades):** Analizamos cuantos bounded contexts dependen de cada archivo y cuantas responsabilidades acumula, lo que predice alta frecuencia de cambios.

Un **hotspot** es un archivo que tiene **alta complejidad Y alta probabilidad de cambio frecuente** — es decir, el codigo mas riesgoso de tocar porque es dificil de entender y se necesita modificar seguido.

---

## 2. Top 3 Hotspots Identificados

### Hotspot #1: `conduit/apps/articles/views.py`

| Metrica | Valor |
|---|---|
| **Complejidad ciclomatica** | Alta — 8 clases/vistas, multiples metodos con logica de negocio |
| **Lineas de codigo** | ~180 LOC |
| **Responsabilidades** | CRUD de articulos, comentarios (crear, listar, eliminar), favoritos (agregar, quitar), feed personalizado, listado de tags |
| **Bounded Contexts que toca** | 3 (Content Management, Engagement, Social Profile) |
| **Acoplamiento** | Importa de `models`, `serializers`, `renderers` locales + `Article`, `Comment`, `Tag` |

**Por que es un hotspot:**

Este archivo es el mas critico del proyecto. Acumula **6 vistas** que pertenecen a **3 bounded contexts diferentes**:

- `ArticleViewSet` → Content Management
- `CommentsListCreateAPIView`, `CommentsDestroyAPIView` → Content Management
- `ArticlesFavoriteAPIView` → Engagement (cross-context con Profile)
- `ArticlesFeedAPIView` → Engagement (cross-context con Profile)
- `TagListAPIView` → Content Management

Cualquier cambio en la logica de articulos, comentarios, favoritos o feed requiere modificar este archivo, generando alto riesgo de regresiones y conflictos en PRs.

**Deuda tecnica especifica:**
- `CommentsDestroyAPIView.destroy()` no verifica que el usuario sea el autor del comentario — cualquier usuario autenticado puede borrar cualquier comentario.
- `ArticleViewSet` no incluye `DestroyModelMixin`, por lo que no se pueden eliminar articulos.
- `get_queryset()` en `ArticleViewSet` encadena filtros sin validacion.
- No hay separacion entre vistas de lectura y escritura.

---

### Hotspot #2: `conduit/apps/authentication/models.py`

| Metrica | Valor |
|---|---|
| **Complejidad ciclomatica** | Media-Alta — `UserManager` + `User` model con JWT logic |
| **Lineas de codigo** | ~120 LOC |
| **Responsabilidades** | Definicion del modelo de usuario, creacion de usuarios, creacion de superusuarios, generacion de JWT tokens, integracion con Django auth |
| **Bounded Contexts que toca** | 2 (IAM + Shared Kernel via herencia) |
| **Acoplamiento** | Base de todo el sistema — `Profile`, `Article`, `Comment` dependen de `User` |

**Por que es un hotspot:**

El modelo `User` es la raiz de toda la cadena de dependencias del sistema. Cualquier cambio aqui (por ejemplo, migrar PyJWT, agregar campos, cambiar el token) impacta potencialmente a todos los demas modulos.

**Deuda tecnica especifica:**
- `_generate_jwt_token()` usa `datetime.now()` en lugar de `datetime.utcnow()` — los tokens tendran timestamps incorrectos si el servidor no esta en UTC.
- `dt.strftime('%s')` es un formato no portable — no funciona en Windows.
- `token.decode('utf-8')` falla con PyJWT >= 2.0 porque `jwt.encode()` ya retorna `str` en vez de `bytes`.
- El token no incluye claims estandar como `iss`, `aud`, ni tiene mecanismo de refresh.
- No hay tests para ningun metodo de `User` ni `UserManager`.

---

### Hotspot #3: `conduit/apps/authentication/serializers.py`

| Metrica | Valor |
|---|---|
| **Complejidad ciclomatica** | Media-Alta — `LoginSerializer.validate()` tiene logica de negocio compleja |
| **Lineas de codigo** | ~130 LOC |
| **Responsabilidades** | Validacion de registro, validacion de login (autenticacion), serializacion/deserializacion de usuarios, actualizacion de perfil (incluye Profile) |
| **Bounded Contexts que toca** | 2 (IAM + Social Profile via `ProfileSerializer` y `profile_data`) |
| **Acoplamiento** | Importa `ProfileSerializer` de profiles, usa `django.contrib.auth.authenticate` |

**Por que es un hotspot:**

Este archivo mezcla logica de validacion, autenticacion y actualizacion de datos entre dos bounded contexts (IAM y Social Profile). `UserSerializer.update()` modifica tanto el `User` como el `Profile` en un solo metodo, rompiendo el principio de single responsibility y acoplando los dos contextos.

**Deuda tecnica especifica:**
- `LoginSerializer.validate()` hace autenticacion dentro de un serializer — mezcla validacion con logica de negocio.
- `UserSerializer.update()` modifica `User` y `Profile` en un solo metodo — acoplamiento directo entre bounded contexts.
- `is_authenticated()` usado como metodo en vez de propiedad (deprecated desde Django 1.10).
- No hay manejo de errores para el caso en que `instance.profile` no exista al hacer update.

---

## 3. Resumen Comparativo de Hotspots

| Rank | Archivo | Complejidad | Acoplamiento | BCs que cruza | Riesgo |
|---|---|---|---|---|---|
| **#1** | `articles/views.py` | Alta | Alto (6 vistas, 3 BCs) | 3 | 🔴 Critico |
| **#2** | `authentication/models.py` | Media-Alta | Muy Alto (raiz de deps) | 2 | 🔴 Critico |
| **#3** | `authentication/serializers.py` | Media-Alta | Alto (cruza IAM + Profile) | 2 | 🟠 Alto |

---

## 4. Plan de Refactoring: Strangler Fig Pattern

### 4.1 Que es el Strangler Fig Pattern?

El patron **Strangler Fig** (propuesto por Martin Fowler) consiste en reemplazar gradualmente un sistema legacy creando nuevos componentes que coexisten con los antiguos, hasta que el sistema viejo queda completamente reemplazado — como una higuera estranguladora que crece alrededor de un arbol huesped.

**Principios que seguimos:**

1. **Nunca reescribimos todo de golpe** — cada refactor es incremental y desplegable.
2. **Lo nuevo y lo viejo coexisten** — usamos routing/facades para dirigir trafico.
3. **Cada paso tiene tests** — no movemos nada sin cobertura.
4. **Cortamos la dependencia antes de mover el codigo** — primero desacoplamos, luego extraemos.

### 4.2 Plan de Refactoring por Hotspot

---

### Fase 1: `articles/views.py` → Separacion de Bounded Contexts

**Riesgo:** 🔴 Critico | **Impacto:** Alto | **Esfuerzo:** Medio | **Prioridad: 1**

**Problema:** Un solo archivo con 6 vistas que pertenecen a 3 bounded contexts.

**Plan Strangler Fig:**

```
ESTADO ACTUAL:
articles/views.py
├── ArticleViewSet          (Content Management)
├── CommentsListCreateAPIView (Content Management)
├── CommentsDestroyAPIView  (Content Management)
├── ArticlesFavoriteAPIView (Engagement)
├── ArticlesFeedAPIView     (Engagement)
└── TagListAPIView          (Content Management)

PASO 1: Crear nuevo modulo sin tocar el viejo
articles/views/
├── __init__.py             ← re-exporta todo (facade)
├── articles.py             ← ArticleViewSet
├── comments.py             ← Comments*
├── tags.py                 ← TagListAPIView
└── engagement.py           ← Favorites + Feed

PASO 2: Mover vistas una por una al nuevo modulo
  - Mover ArticleViewSet → articles.py
  - Actualizar __init__.py para re-exportar
  - Verificar que todos los tests pasan
  - Repetir para cada grupo

PASO 3: Eliminar el archivo monolitico
  - Cuando __init__.py solo tiene imports, el viejo views.py ya no existe
  - urls.py sigue funcionando porque importa del mismo path
```

**Acciones concretas:**

| Paso | Accion | Validacion |
|---|---|---|
| 1.1 | Escribir tests para las 6 vistas actuales (no existen) | Tests pasan con codigo actual |
| 1.2 | Crear `articles/views/__init__.py` que re-exporte todo | `from .views import *` sigue funcionando |
| 1.3 | Extraer `ArticleViewSet` a `articles/views/articles.py` | Tests pasan, endpoints responden igual |
| 1.4 | Extraer vistas de comentarios a `articles/views/comments.py` | Tests pasan |
| 1.5 | Extraer `ArticlesFavoriteAPIView` y `ArticlesFeedAPIView` a `articles/views/engagement.py` | Tests pasan |
| 1.6 | Extraer `TagListAPIView` a `articles/views/tags.py` | Tests pasan |
| 1.7 | Agregar verificacion de autoria en `CommentsDestroyAPIView` | Bug fix: solo el autor puede borrar |
| 1.8 | Eliminar `articles/views.py` original | Todos los imports vienen del package |

---

### Fase 2: `authentication/models.py` → Extraccion de JWT

**Riesgo:** 🔴 Critico | **Impacto:** Alto | **Esfuerzo:** Medio | **Prioridad: 2**

**Problema:** El modelo `User` contiene logica de generacion de JWT, esta acoplado a una version obsoleta de PyJWT, y usa formatos no portables.

**Plan Strangler Fig:**

```
ESTADO ACTUAL:
authentication/models.py
└── User
    ├── campos del modelo
    ├── @property token → _generate_jwt_token()  ← AQUI ESTA EL PROBLEMA
    └── _generate_jwt_token()                     ← PyJWT 1.4 hardcoded

PASO 1: Crear servicio de tokens separado (lo nuevo)
authentication/tokens.py   ← NUEVO
├── generate_token(user)    ← compatible con PyJWT 2.x
├── decode_token(token)     ← centraliza decodificacion
└── TOKEN_EXPIRY_DAYS = 60

PASO 2: Hacer que User.token use el nuevo servicio
User._generate_jwt_token() → llama a tokens.generate_token(self)
backends.py._authenticate_credentials() → llama a tokens.decode_token()

PASO 3: Actualizar PyJWT a 2.x
  - Solo hay que cambiar tokens.py (un archivo, un lugar)
  - User.token sigue funcionando via facade

PASO 4: Cleanup
  - Eliminar _generate_jwt_token() de User
  - User.token llama directo a tokens.generate_token()
```

**Acciones concretas:**

| Paso | Accion | Validacion |
|---|---|---|
| 2.1 | Escribir tests para `User.token` y `JWTAuthentication` | Tests pasan con codigo actual |
| 2.2 | Crear `authentication/tokens.py` con `generate_token()` y `decode_token()` | Unit tests del nuevo modulo pasan |
| 2.3 | Modificar `User._generate_jwt_token()` para delegar a `tokens.generate_token()` | Tests de integracion pasan |
| 2.4 | Modificar `backends.py` para usar `tokens.decode_token()` | Login/auth sigue funcionando |
| 2.5 | Actualizar PyJWT a 2.x en `requirements.txt` | Solo `tokens.py` necesita ajuste |
| 2.6 | Agregar claims estandar (`iss`, `aud`, `iat`) y refresh token | Mejora de seguridad |
| 2.7 | Eliminar `_generate_jwt_token()` de `User` | `User.token` → `tokens.generate_token(self)` |

---

### Fase 3: `authentication/serializers.py` → Separacion de Concerns

**Riesgo:** 🟠 Alto | **Impacto:** Medio | **Esfuerzo:** Bajo | **Prioridad: 3**

**Problema:** `LoginSerializer` hace autenticacion, `UserSerializer` modifica dos modelos de bounded contexts diferentes.

**Plan Strangler Fig:**

```
ESTADO ACTUAL:
authentication/serializers.py
├── RegistrationSerializer     ← OK, simple
├── LoginSerializer            ← PROBLEMA: authenticate() dentro de validate()
└── UserSerializer             ← PROBLEMA: update() modifica User Y Profile

PASO 1: Extraer logica de autenticacion
authentication/services.py    ← NUEVO
└── authenticate_user(email, password)
    ├── valida credenciales
    ├── verifica is_active
    └── retorna user o raise

LoginSerializer.validate() → llama a services.authenticate_user()

PASO 2: Separar update de Profile
UserSerializer.update():
  ANTES: modifica User + Profile en un solo metodo
  DESPUES: modifica User, luego emite signal/llama a ProfileSerializer

PASO 3: Cleanup
  - LoginSerializer.validate() solo coordina, no autentica
  - UserSerializer.update() solo toca User
  - Profile se actualiza via su propio serializer
```

**Acciones concretas:**

| Paso | Accion | Validacion |
|---|---|---|
| 3.1 | Escribir tests para login, registro y update de usuario | Tests pasan con codigo actual |
| 3.2 | Crear `authentication/services.py` con `authenticate_user()` | Unit tests pasan |
| 3.3 | Refactorizar `LoginSerializer.validate()` para usar el servicio | Tests de integracion pasan |
| 3.4 | Separar la logica de update de Profile fuera de `UserSerializer` | Update de user y profile siguen funcionando |
| 3.5 | Cambiar `is_authenticated()` a `is_authenticated` (propiedad) | Eliminar deprecation warning |

---

## 5. Roadmap de Refactoring Priorizado

```
Semana 1-2          Semana 3-4          Semana 5-6          Semana 7-8
─────────────────────────────────────────────────────────────────────
│                   │                   │                   │
│  FASE 0:          │  FASE 1:          │  FASE 2:          │  FASE 3:
│  Escribir tests   │  Separar vistas   │  Extraer JWT      │  Separar
│  para los 3       │  de articles/     │  service de       │  concerns en
│  hotspots         │  views.py         │  auth/models.py   │  serializers
│  (prerequisito)   │                   │                   │
│                   │  Fix: comments    │  Upgrade PyJWT    │  Crear
│  Setup CI/CD      │  auth bug         │  a 2.x            │  services.py
│  pipeline         │                   │                   │
─────────────────────────────────────────────────────────────────────
    RIESGO: Bajo        RIESGO: Medio       RIESGO: Alto        RIESGO: Bajo
    IMPACTO: Alto       IMPACTO: Alto       IMPACTO: Alto       IMPACTO: Medio
```

### Principios del Roadmap

1. **Tests primero:** No refactorizamos nada sin cobertura previa (Fase 0 es prerequisito).
2. **Mayor riesgo primero:** `articles/views.py` se separa antes porque cada cambio ahi afecta 3 bounded contexts.
3. **Cambios incrementales:** Cada paso del Strangler Fig es un PR independiente que pasa CI.
4. **Coexistencia:** En cada fase, el codigo viejo y nuevo coexisten hasta que el viejo se elimina.

---

## 6. Metricas de Exito del Refactoring

| Metrica | Antes del refactoring | Objetivo post-refactoring |
|---|---|---|
| Archivos por bounded context | Mezclados (1 archivo = 3 BCs) | 1 archivo = 1 responsabilidad |
| Complejidad de `articles/views.py` | ~180 LOC, CC alta | Archivo eliminado, reemplazado por 4 modulos |
| Complejidad de `auth/models.py` | CC media-alta, JWT acoplado | JWT extraido a `tokens.py`, modelo limpio |
| Cobertura de tests (hotspots) | 0% | >= 80% |
| Bugs conocidos | 1 (comments auth) | 0 |
| Dependencias obsoletas (JWT) | PyJWT 1.4 | PyJWT 2.x |
