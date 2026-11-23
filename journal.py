"""Записи журнала и их хранение в JSON."""

import json
from dataclasses import asdict, dataclass, replace
from pathlib import Path
from tempfile import NamedTemporaryFile

OPEN = "Открыта"
CLOSED = "Закрыта"


@dataclass(frozen=True)
class Ticket:
    number: int
    description: str
    status: str


def read_tickets(path: Path) -> list[Ticket]:
    records = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(records, list):
        raise ValueError("В файле должен быть список заявок.")

    tickets = []
    numbers = set()
    for record in records:
        if not isinstance(record, dict):
            raise ValueError("Неверный формат записи.")
        number = record.get("number")
        description = record.get("description")
        status = record.get("status")
        if type(number) is not int or number < 1 or number in numbers:
            raise ValueError("Номера заявок должны быть уникальными целыми числами от 1.")
        if not isinstance(description, str) or not description.strip():
            raise ValueError("У каждой заявки должно быть описание.")
        if status not in (OPEN, CLOSED):
            raise ValueError("В файле есть заявка с неизвестным статусом.")
        tickets.append(Ticket(number, description, status))
        numbers.add(number)
    return tickets


class Journal:
    """Меняет список в памяти только после успешной записи на диск."""

    def __init__(self, path: Path):
        self.path = path
        try:
            self.tickets = read_tickets(path)
        except FileNotFoundError:
            self._save([])

    def add(self, description: str) -> Ticket:
        description = description.strip()
        if not description:
            raise ValueError("Введите описание проблемы.")
        number = max((ticket.number for ticket in self.tickets), default=0) + 1
        ticket = Ticket(number, description, OPEN)
        self._save([*self.tickets, ticket])
        return ticket

    def close(self, number: int) -> None:
        for index, ticket in enumerate(self.tickets):
            if ticket.number == number:
                if ticket.status == OPEN:
                    tickets = self.tickets.copy()
                    tickets[index] = replace(ticket, status=CLOSED)
                    self._save(tickets)
                return
        raise ValueError(f"Заявка № {number} не найдена.")

    def _save(self, tickets: list[Ticket]) -> None:
        self._write(self.path, tickets)
        self.tickets = tickets

    def backup(self, path: Path) -> None:
        lock_path = self.path.with_name(self.path.name + ".lock")
        if path.resolve() in (self.path.resolve(), lock_path.resolve()):
            raise ValueError("Выберите отдельный файл для резервной копии.")
        self._write(path, self.tickets)

    def restore(self, tickets: list[Ticket]) -> None:
        self._save(tickets)

    @staticmethod
    def _write(path: Path, tickets: list[Ticket]) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        contents = json.dumps([asdict(ticket) for ticket in tickets], ensure_ascii=False, indent=2)
        temporary = NamedTemporaryFile(
            mode="w", encoding="utf-8", dir=path.parent, delete=False
        )
        temp_path = Path(temporary.name)
        # Замена после полной записи оставляет прежний JSON при ошибке сохранения.
        try:
            with temporary:
                temporary.write(contents + "\n")
            temp_path.replace(path)
        finally:
            temp_path.unlink(missing_ok=True)
