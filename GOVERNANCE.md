# Governance & Quality Strategy

## 1. CI Pipeline — GitHub Actions

### Descripcion General

Configuramos un pipeline de CI en GitHub Actions ([`.github/workflows/ci.yml`](./.github/workflows/ci.yml)) que se ejecuta automaticamente en cada Pull Request hacia `main` o `develop`, y en cada push a `main`.

El pipeline tiene dos jobs:

| Job | Que hace | Falla si... |
|---|---|---|
| **quality-checks** | Mide complejidad ciclomatica (radon/xenon), cobertura de tests (pytest-cov) y lint (flake8) | La complejidad supera grado C en alguna funcion, o la cobertura cae debajo del 60% |
| **sonarqube** | Ejecuta analisis SonarQube con los reportes generados | No pasa los Quality Gates definidos en SonarQube |

### Herramientas Integradas

| Herramienta | Proposito | Configuracion |
|---|---|---|
| **radon** | Mide Cyclomatic Complexity por funcion/clase/modulo | `radon cc conduit/ -a -s` |
| **xenon** | Quality gate de complejidad — falla el build si se exceden umbrales | `--max-absolute C --max-modules B --max-average A` |
| **pytest + pytest-cov** | Ejecuta tests y mide Code Coverage | `coverage run --source=conduit -m pytest` |
| **coverage** | Genera reportes en XML (SonarQube) y JSON (gate check) | `coverage xml`, `coverage json` |
| **flake8** | Linting / style checks | `--max-line-length=120` |
| **SonarQube** | Analisis integral de calidad (bugs, code smells, vulnerabilidades, duplicacion) | [`sonar-project.properties`](./sonar-project.properties) |

### Flujo del Pipeline

```
PR abierto / push a main
        │
        ▼
┌─────────────────────────────┐
│   quality-checks            │
│                             │
│  1. Checkout + Setup Py3.10 │
│  2. Install dependencies    │
│  3. radon cc (complexity)   │
│  4. xenon gate (fail/pass)  │
│  5. radon mi (maint. index) │
│  6. pytest + coverage       │
│  7. Coverage gate (fail if  │
│     < 60%, warn if < 80%)   │
│  8. flake8 lint             │
│  9. Upload artifacts        │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│   sonarqube                 │
│                             │
│  1. Download artifacts      │
│  2. SonarQube scan          │
│  3. Quality Gate check      │
└─────────────────────────────┘
```

### Quality Gates Definidos

Definimos los siguientes umbrales que deben cumplirse para que un PR sea aprobado:

| Metrica | Umbral minimo | Umbral recomendado | Accion si falla |
|---|---|---|---|
| **Cyclomatic Complexity** (por funcion) | <= 10 (grado C) | <= 5 (grado A) | Build falla |
| **Cyclomatic Complexity** (promedio modulo) | <= 7 (grado B) | <= 5 (grado A) | Build falla |
| **Code Coverage** (global) | >= 60% | >= 80% | Build falla / warning |
| **Code Coverage** (codigo nuevo) | >= 80% | >= 90% | SonarQube falla |
| **Duplicated Lines** (codigo nuevo) | <= 3% | <= 1% | SonarQube warning |
| **Blocker Issues** (nuevos) | 0 | 0 | SonarQube falla |
| **Critical Issues** (nuevos) | 0 | 0 | SonarQube falla |
| **Code Smells** (nuevos por PR) | <= 5 | 0 | SonarQube warning |

---

## 2. Dashboard de Metricas DORA

Las metricas DORA (DevOps Research and Assessment) miden la eficiencia y confiabilidad del proceso de entrega de software. A continuacion definimos como medimos cada una y los valores objetivo para este proyecto.

### 2.1 Definicion de las 4 Metricas DORA

#### Deployment Frequency (Frecuencia de Despliegue)

> Con que frecuencia desplegamos a produccion?

| Campo | Detalle |
|---|---|
| **Como medimos** | Conteo de merges a `main` que disparan el pipeline completo |
| **Fuente de datos** | GitHub API: commits/merges a `main` por periodo |
| **Valor actual** | N/A (proyecto legacy sin CD) |
| **Objetivo** | >= 1 deploy por semana (nivel "High Performer") |
| **Herramienta** | GitHub Actions + GitHub Insights |

#### Lead Time for Changes (Tiempo de Entrega)

> Cuanto tiempo pasa desde el primer commit de un cambio hasta que esta en produccion?

| Campo | Detalle |
|---|---|
| **Como medimos** | Tiempo entre el primer commit de un PR y el merge a `main` |
| **Fuente de datos** | GitHub API: `created_at` del PR vs `merged_at` |
| **Valor actual** | N/A |
| **Objetivo** | < 2 dias (nivel "High Performer") |
| **Herramienta** | GitHub Actions metrics / custom script |

#### Change Failure Rate (Tasa de Fallo de Cambios)

> Que porcentaje de despliegues causan un fallo en produccion?

| Campo | Detalle |
|---|---|
| **Como medimos** | (Deploys que requirieron rollback o hotfix) / (Total de deploys) x 100 |
| **Fuente de datos** | GitHub Issues etiquetadas `bug:production` + tags de rollback |
| **Valor actual** | N/A |
| **Objetivo** | < 15% (nivel "High Performer") |
| **Herramienta** | GitHub Issues + Labels + Pipeline logs |

#### Mean Time to Recovery (Tiempo Medio de Recuperacion)

> Cuanto tiempo tardamos en recuperarnos de un fallo en produccion?

| Campo | Detalle |
|---|---|
| **Como medimos** | Tiempo entre la apertura de un issue `bug:production` y su cierre (deploy del fix) |
| **Fuente de datos** | GitHub Issues: `created_at` vs `closed_at` para issues con label `bug:production` |
| **Valor actual** | N/A |
| **Objetivo** | < 24 horas (nivel "High Performer") |
| **Herramienta** | GitHub Issues + Pipeline timestamps |

### 2.2 Dashboard Visual

```
┌─────────────────────────────────────────────────────────────────────┐
│                    DORA METRICS DASHBOARD                          │
├─────────────────────┬───────────────────────────────────────────────┤
│                     │                                               │
│  DEPLOYMENT FREQ.   │  LEAD TIME FOR CHANGES                       │
│  ┌───────────────┐  │  ┌───────────────┐                           │
│  │  Target:      │  │  │  Target:      │                           │
│  │  1x / week    │  │  │  < 2 days     │                           │
│  │               │  │  │               │                           │
│  │  Actual: N/A  │  │  │  Actual: N/A  │                           │
│  │  (no CD yet)  │  │  │  (no PRs yet) │                           │
│  └───────────────┘  │  └───────────────┘                           │
│                     │                                               │
├─────────────────────┼───────────────────────────────────────────────┤
│                     │                                               │
│  CHANGE FAILURE     │  MEAN TIME TO RECOVERY                       │
│  RATE               │                                               │
│  ┌───────────────┐  │  ┌───────────────┐                           │
│  │  Target:      │  │  │  Target:      │                           │
│  │  < 15%        │  │  │  < 24 hours   │                           │
│  │               │  │  │               │                           │
│  │  Actual: N/A  │  │  │  Actual: N/A  │                           │
│  │  (no prod)    │  │  │  (no prod)    │                           │
│  └───────────────┘  │  └───────────────┘                           │
│                     │                                               │
├─────────────────────┴───────────────────────────────────────────────┤
│  QUALITY GATES STATUS                                               │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐      │
│  │ Complexity │ │  Coverage  │ │  Duplication│ │ SonarQube  │      │
│  │  <= C: ✅   │ │  >= 60%:✅  │ │  <= 3%: ✅  │ │  Gate: ✅   │      │
│  └────────────┘ └────────────┘ └────────────┘ └────────────┘      │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.3 Implementacion del Dashboard

Para rastrear las metricas DORA en la practica, proponemos:

1. **Corto plazo (ahora):** Documentar los targets y medir manualmente desde GitHub Insights y los logs del pipeline.
2. **Mediano plazo:** Implementar un GitHub Action que calcule las metricas automaticamente al final de cada semana y las publique como GitHub Pages o como un comment en un issue fijado.
3. **Largo plazo:** Integrar con herramientas como Sleuth, LinearB o el DORA dashboard nativo de GitHub (si se habilita GitHub Advanced).

---

## 3. Configuracion de SonarQube

### 3.1 Archivo de Configuracion

Creamos [`sonar-project.properties`](./sonar-project.properties) en la raiz del repositorio con la siguiente configuracion:

- **Fuentes:** `conduit/` (excluyendo migraciones, `__pycache__`, archivos estaticos)
- **Cobertura:** Lee `coverage.xml` generado por el job `quality-checks`
- **Python version:** 3.10 (versión objetivo post-migracion)

### 3.2 Quality Gates en SonarQube

Configuramos los siguientes Quality Gates en el servidor SonarQube:

| Condicion | Metrica | Operador | Valor |
|---|---|---|---|
| Cobertura en codigo nuevo | Coverage on New Code | >= | 80% |
| Duplicacion en codigo nuevo | Duplicated Lines on New Code | <= | 3% |
| Rating de mantenibilidad | Maintainability Rating on New Code | = | A |
| Rating de confiabilidad | Reliability Rating on New Code | = | A |
| Rating de seguridad | Security Rating on New Code | = | A |
| Issues bloqueantes | New Blocker Issues | = | 0 |
| Issues criticos | New Critical Issues | = | 0 |

### 3.3 Secretos Requeridos en GitHub

Para que el pipeline funcione, debemos configurar los siguientes secrets en el repositorio:

| Secret | Descripcion |
|---|---|
| `SONAR_TOKEN` | Token de autenticacion del proyecto en SonarQube |
| `SONAR_HOST_URL` | URL del servidor SonarQube (ej: `https://sonarqube.example.com`) |

Se configuran en: **Settings → Secrets and variables → Actions → New repository secret**

---

## 4. Resumen de la Estrategia de Governance

Nuestra estrategia de governance se basa en tres pilares:

### Pilar 1: Prevencion (Shift-Left)

Detectamos problemas lo antes posible mediante quality gates automatizados en el CI que bloquean PRs que degradan metricas.

### Pilar 2: Visibilidad

El dashboard DORA y los reportes de SonarQube nos dan visibilidad continua sobre la salud del proyecto, permitiendo decisiones informadas.

### Pilar 3: Mejora Continua

Los umbrales de quality gates estan definidos con un valor minimo (para no bloquear el progreso) y un valor recomendado (hacia donde queremos llegar). A medida que modernizamos el proyecto, iremos subiendo los umbrales.
