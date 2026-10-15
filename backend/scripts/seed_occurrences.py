import asyncio
import uuid
from datetime import datetime, timedelta
import redis.asyncio as redis

from shared.config import settings
from shared.database import AsyncSessionLocal
from shared.models import Occurrence, SeverityEnum, OccurrenceStatusEnum
from sqlalchemy.future import select

SEED_DATA = [
    {
        "category": "flood",
        "severity": SeverityEnum.CRITICAL,
        "description": "Ponto intransitável por acúmulo de água das fortes chuvas. Risco alto de inundação de veículos.",
        "latitude": "-23.548900",
        "longitude": "-46.632200",
        "address": "Av. do Estado x Rua 25 de Março",
        "city": "São Paulo",
        "state": "SP",
        "minutes_ago": 15,
    },
    {
        "category": "fire",
        "severity": SeverityEnum.CRITICAL,
        "description": "Foco de queimada em vegetação seca com fumaça densa espalhando para pistas próximas. Bombeiros acionados.",
        "latitude": "-23.587400",
        "longitude": "-46.657600",
        "address": "Av. Pedro Álvares Cabral, Parque Ibirapuera",
        "city": "São Paulo",
        "state": "SP",
        "minutes_ago": 35,
    },
    {
        "category": "road_block",
        "severity": SeverityEnum.HIGH,
        "description": "Árvore de grande porte caiu sobre a fiação elétrica e bloqueia duas faixas da avenida.",
        "latitude": "-23.582100",
        "longitude": "-46.639400",
        "address": "Rua Domingos de Morais, 1200 - Vila Mariana",
        "city": "São Paulo",
        "state": "SP",
        "minutes_ago": 50,
    },
    {
        "category": "pollution",
        "severity": SeverityEnum.HIGH,
        "description": "Forte odor químico e mancha escura de efluentes industriais com grande impacto na fauna do rio.",
        "latitude": "-23.519200",
        "longitude": "-46.631800",
        "address": "Ponte das Bandeiras - Marginal Tietê",
        "city": "São Paulo",
        "state": "SP",
        "minutes_ago": 120,
    },
    {
        "category": "extreme_heat",
        "severity": SeverityEnum.MEDIUM,
        "description": "Ilha de calor severa com sensação térmica de 38°C e umidade relativa do ar em 18%.",
        "latitude": "-23.561400",
        "longitude": "-46.656500",
        "address": "Av. Paulista, 1578 - Bela Vista",
        "city": "São Paulo",
        "state": "SP",
        "minutes_ago": 180,
    },
    {
        "category": "water_leak",
        "severity": SeverityEnum.MEDIUM,
        "description": "Vazamento contínuo de água tratada na calçada há mais de 6 horas, lavando o asfalto.",
        "latitude": "-23.567000",
        "longitude": "-46.685000",
        "address": "Rua dos Pinheiros, 450 - Pinheiros",
        "city": "São Paulo",
        "state": "SP",
        "minutes_ago": 240,
    },
    {
        "category": "trash",
        "severity": SeverityEnum.MEDIUM,
        "description": "Grande volume de entulho de construção e lixo doméstico descartado ilegalmente bloqueando calçada.",
        "latitude": "-23.535000",
        "longitude": "-46.621000",
        "address": "Rua Carnot - Pari",
        "city": "São Paulo",
        "state": "SP",
        "minutes_ago": 360,
    },
    {
        "category": "pollution",
        "severity": SeverityEnum.LOW,
        "description": "Ponto de monitoramento comunitário: ar com qualidade aceitável, mas tráfego intenso gerando fuligem moderada.",
        "latitude": "-23.539000",
        "longitude": "-46.602000",
        "address": "Radial Leste (Alcântara Machado) - Mooca",
        "city": "São Paulo",
        "state": "SP",
        "minutes_ago": 480,
    },
]

async def seed():
    print("🌱 Iniciando inserção de ocorrências de teste...")
    async with AsyncSessionLocal() as session:
        for item in SEED_DATA:
            # Check if exists by address or description prefix
            result = await session.execute(
                select(Occurrence).filter(Occurrence.address == item["address"])
            )
            existing = result.scalars().first()
            if existing:
                print(f"⏩ Já existe: {item['address']}")
                continue

            created_time = datetime.utcnow() - timedelta(minutes=item["minutes_ago"])
            occ = Occurrence(
                id=uuid.uuid4(),
                client_event_id=uuid.uuid4(),
                category=item["category"],
                severity=item["severity"],
                description=item["description"],
                latitude=item["latitude"],
                longitude=item["longitude"],
                location=f"SRID=4326;POINT({item['longitude']} {item['latitude']})",
                address=item["address"],
                city=item["city"],
                state=item["state"],
                status=OccurrenceStatusEnum.ACTIVE,
                created_at=created_time,
                updated_at=created_time,
            )
            session.add(occ)
            print(f"✅ Inserido: {item['category']} ({item['severity'].value}) - {item['address']}")

        await session.commit()

    # Clear redis cache
    try:
        redis_client = redis.from_url(settings.REDIS_URL, decode_responses=True)
        keys = await redis_client.keys("occurrences:nearby*")
        if keys:
            await redis_client.delete(*keys)
            print(f"🧹 Cache do Redis limpo ({len(keys)} chaves removidas).")
        await redis_client.close()
    except Exception as e:
        print(f"Aviso ao limpar cache Redis: {e}")

    print("🎉 Seed concluído com sucesso!")

if __name__ == "__main__":
    asyncio.run(seed())
