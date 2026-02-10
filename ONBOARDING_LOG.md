# Onboarding Log — Conduit (Django DRF)

## Resumen

Este documento registra el proceso de configuración y puesta en marcha del proyecto **Conduit** ([productionready-django-api](https://github.com/gothinkster/productionready-django-api)), identificando los puntos de fricción que un nuevo desarrollador enfrentaría al intentar ejecutar y modificar el sistema.

**Veredicto general:** El proyecto presenta fallas estructurales críticas de mantenibilidad, seguridad y experiencia de desarrollo las cuales representan barreras significativas para nuevos contribuidores. Las dependencias obsoletas (Python 3.5, Django 1.10) hacen que sea **prácticamente imposible** ejecutar el proyecto en un sistema operativo moderno sin intervención manual considerable.

---

## Paso a paso del setup intentado

| # | Paso | Instrucción del README | Resultado | Tiempo |
|---|---|---|---|---|
| 1 | Clonar repositorio | `git clone git@github.com:gothinkster/productionready-django-api.git` | ⚠️ La URL del README apunta a un repo que puede estar archivado | 1 min |
| 2 | Instalar pyenv | Enlace a repo de pyenv | ✅ Funciona, pero es una dependencia extra no estándar | 5-15 min |
| 3 | Instalar pyenv-virtualenv | Enlace a repo | ⚠️ Plugin adicional, no todo el mundo lo usa | 5-10 min |
| 4 | Instalar Python 3.5.2 | `pyenv install 3.5.2` | ❌ **Falla en sistemas modernos** — incompatibilidad con OpenSSL 3.x | bloqueante |
| 5 | Crear virtualenv | `pyenv virtualenv 3.5.2 productionready` | ❌ Depende de paso 4 | bloqueante |
| 6 | Instalar dependencias | `pip install -r requirements.txt` | ❌ Django 1.10.5 es incompatible con Python 3.10+ | bloqueante |
| 7 | Ejecutar migraciones | `python manage.py migrate` | ✅ Si se logra resolver lo anterior | 30 seg |
| 8 | Ejecutar servidor | `python manage.py runserver` | ✅ Condicional | 10 seg |

**Tiempo estimado total de onboarding:** 2-4 horas (si se resuelven los problemas de compatibilidad manualmente).

---

## Friction Points Identificados

### 🔴 FP-01: Python 3.5.2 está en End of Life (CRÍTICO)

**Dónde:** README.md paso 5, `.python-version` implícito

**Descripción:** Python 3.5 llegó a End of Life en septiembre de 2020. Compilar esta versión en sistemas operativos modernos (Ubuntu 22.04+, macOS Ventura+, Fedora 37+) **falla** porque:
- OpenSSL 3.x no es compatible con los bindings de Python 3.5
- Algunos paquetes del sistema necesarios para compilar ya no están disponibles
- pyenv no puede construir Python 3.5.2 sin parches manuales

**Impacto:** Bloqueante. Un desarrollador nuevo no puede arrancar el proyecto sin investigar workarounds.

**Solución propuesta:** Actualizar a Python 3.10+ y ajustar las dependencias.

---

### 🔴 FP-02: Dependencias extremadamente desactualizadas (CRÍTICO)

**Dónde:** `requirements.txt`

**Descripción:** El proyecto depende de librerías fuera de soporte y con APIs obsoletas, lo que introduce riesgos de seguridad y bloquea su ejecución confiable en entornos modernos.

**Detalle:**

| Paquete | Versión actual | Última versión | Años de atraso |
|---|---|---|---|
| Django | 1.10.5 (feb 2017) | 5.1+ | ~9 años |
| djangorestframework | 3.4.4 | 3.15+ | ~8 años |
| PyJWT | 1.4.2 | 2.9+ | ~8 años |
| django-cors-middleware | 1.3.1 | 1.3.1 (deprecated) | Reemplazado por django-cors-headers |
| six | 1.10.0 | Innecesario en Python 3 | N/A |

**Impacto:** 
- Django 1.10 no recibe parches de seguridad desde diciembre 2017
- PyJWT 1.4 tiene un API diferente al 2.x (`jwt.encode()` retorna `bytes` vs `str`)
- `is_authenticated()` fue cambiado de método a propiedad en Django 1.10+, causando deprecation warnings
- `six` es innecesario si se migra a Python 3 puro

---

### 🔴 FP-03: SECRET_KEY hardcodeada en settings.py (SEGURIDAD)

**Dónde:** `conduit/settings.py` línea 22

```python
SECRET_KEY = '2^f+3@v7$v1f8yt0!s)3-1t$)tlp+xm17=*g))_xoi&&9m#2a&'
```

**Descripción:** El valor de SECRET_KEY está hardcodeado en el código fuente, lo que expone un secreto crítico y permite la falsificación de tokens JWT si el repositorio es accesible.

**Impacto:** Esta clave se usa para firmar los tokens JWT. Si alguien la conoce, puede fabricar tokens arbitrarios y autenticarse como cualquier usuario.

**Solución propuesta:** Mover a variable de entorno con `os.environ.get('SECRET_KEY')` o usar `django-environ`.

---

### 🟠 FP-04: No existe Docker ni docker-compose (MEDIO)

**Dónde:** Raíz del proyecto — ausencia de `Dockerfile`, `docker-compose.yml`

**Descripción:** La ausencia de contenedores obliga a realizar un setup manual complejo y frágil, aumentando significativamente el tiempo y la probabilidad de error durante el onboarding.

**Impacto:** Todo desarrollador nuevo debe:
1. Instalar pyenv (herramienta no universal)
2. Instalar pyenv-virtualenv (plugin adicional)
3. Compilar Python 3.5.2 (ver FP-01)
4. Instalar dependencias manualmente

Con Docker, todo esto se reduciría a `docker-compose up`.

---

### 🟠 FP-05: No hay suite de tests (MEDIO)

**Dónde:** Ausencia total — no hay directorio `tests/`, no hay `conftest.py`, no hay `pytest.ini` ni `setup.cfg` con configuración de tests.

**Descripción:** La ausencia total de una suite de tests impide validar el correcto funcionamiento del sistema y elimina cualquier confianza al realizar cambios o refactors.

**Impacto:**
- No se puede verificar que el proyecto funciona después del setup
- No hay red de seguridad para refactors
- No hay ejemplos de uso de los endpoints (que los tests normalmente proveen)

---

### 🟠 FP-06: README incompleto (MEDIO)

**Dónde:** `README.md`

**Descripción:** El README no provee la información mínima necesaria para ejecutar y entender el sistema, lo que aumenta la fricción del onboarding y fuerza a depender del código fuente para tareas básicas.

**Lo que falta:**
- Cómo ejecutar el servidor (`python manage.py runserver`)
- Cómo ejecutar migraciones (`python manage.py migrate`)
- Lista de endpoints de la API
- Cómo ejecutar tests (no hay tests, pero debería mencionarse)
- Variables de entorno necesarias
- Cómo crear un superusuario
- Ejemplo de request/response para al menos un endpoint

**Lo que sí tiene:**
- Pasos de instalación con pyenv (aunque desactualizados)
- Enlace al tutorial de Thinkster

---

### 🟠 FP-07: `DEBUG = True` sin control por entorno (MEDIO)

**Dónde:** `conduit/settings.py` línea 27

```python
DEBUG = True
```

**Descripción:** La configuración `DEBUG = True` está activada de forma permanente, lo que puede exponer información sensible del sistema si el código se despliega sin ajustes por entorno.

**Impacto:** Si alguien despliega este código sin cambiar settings, Django expone stack traces completos y información sensible del sistema.

---

### 🟡 FP-08: `jwt.decode()` con bare except (BAJO-MEDIO)

**Dónde:** `conduit/apps/authentication/backends.py` líneas 70-72

```python
try:
    payload = jwt.decode(token, settings.SECRET_KEY)
except:
    msg = 'Invalid authentication. Could not decode token.'
    raise exceptions.AuthenticationFailed(msg)
```

**Descripción:** El manejo de errores en jwt.decode() es demasiado amplio y omite validaciones explícitas, lo que puede ocultar fallos reales y debilitar la seguridad de la autenticación.

**Detalle:**
1. `except:` sin especificar excepción captura **todo**, incluyendo `KeyboardInterrupt` y `SystemExit`.
2. No se especifica el algoritmo (`algorithms=['HS256']`), lo que en versiones modernas de PyJWT es obligatorio.
3. Oculta errores que no son de JWT (por ejemplo, errores de conexión a BD).

---

### 🟡 FP-09: Uso de `is` para comparar enteros (BAJO)

**Dónde:** `conduit/apps/articles/signals.py` línea 23

```python
if len(parts) is 1:
```

**Descripción:** Se utiliza el operador is para comparar valores enteros, lo que es semánticamente incorrecto y puede provocar comportamientos inesperados en versiones modernas de Python.

**Impacto:** En Python 3.8+ esto genera `SyntaxWarning: "is" with a literal. Did you mean "=="?`. Funciona por coincidencia (Python cachea enteros pequeños), pero es técnicamente incorrecto.

---

### 🟡 FP-10: `is_authenticated()` usado como método (BAJO)

**Dónde:** 
- `conduit/apps/articles/serializers.py` línea 67
- `conduit/apps/profiles/serializers.py` línea 28

```python
if not request.user.is_authenticated():
```

**Descripción:** El uso de is_authenticated() como método corresponde a una API obsoleta y genera warnings deprecados que pueden derivar en errores al migrar a versiones modernas de Django.

**Impacto:** `is_authenticated` fue cambiado de método invocable a propiedad en Django 1.10. Llamarlo como método funciona pero genera `DeprecationWarning`, y en Django 2.0+ puede causar comportamiento inesperado.

---

### 🟡 FP-11: Sin `.env` ni gestión de configuración por entorno (BAJO)

**Dónde:** Ausencia de `.env`, `django-environ`, o `python-dotenv` en el proyecto

**Descripción:** El proyecto carece de un mecanismo estándar para gestionar configuración por entorno, lo que obliga a modificar el código para cambiar ajustes entre desarrollo, staging y producción.

**Impacto:** No hay forma estándar de cambiar configuración entre desarrollo, staging y producción sin editar `settings.py` directamente.

---

## Resumen de Friction Points

| ID | Severidad | Categoría | Descripción |
|---|---|---|---|
| FP-01 | 🔴 Crítico | Entorno | Python 3.5.2 EOL, no compila en sistemas modernos |
| FP-02 | 🔴 Crítico | Dependencias | Django 1.10, DRF 3.4, PyJWT 1.4 — todo obsoleto |
| FP-03 | 🔴 Crítico | Seguridad | SECRET_KEY hardcodeada en settings.py |
| FP-04 | 🟠 Medio | DevEx | Sin Docker/docker-compose |
| FP-05 | 🟠 Medio | Calidad | Sin suite de tests |
| FP-06 | 🟠 Medio | Documentación | README incompleto |
| FP-07 | 🟠 Medio | Seguridad | DEBUG=True sin control por entorno |
| FP-08 | 🟡 Bajo-Medio | Seguridad/Código | jwt.decode() con bare except y sin algoritmo |
| FP-09 | 🟡 Bajo | Código | `is` en vez de `==` para comparar enteros |
| FP-10 | 🟡 Bajo | Código | `is_authenticated()` como método deprecated |
| FP-11 | 🟡 Bajo | Configuración | Sin gestión de variables de entorno |

---

## Recomendaciones prioritarias

1. **Actualizar Python a 3.10+** y todas las dependencias a versiones LTS actuales (Django 4.2+, DRF 3.14+, PyJWT 2.x).
2. **Agregar Dockerfile + docker-compose.yml** para que el onboarding sea `docker-compose up` y nada más.
3. **Mover secretos a variables de entorno** usando `django-environ` o `python-dotenv`.
4. **Agregar tests** con `pytest-django` — al menos smoke tests para cada endpoint.
5. **Completar el README** con instrucciones de ejecución, endpoints y ejemplos.
6. **Corregir los warnings** de código (`is` → `==`, `is_authenticated()` → `is_authenticated`, bare `except` → `except jwt.DecodeError`).
