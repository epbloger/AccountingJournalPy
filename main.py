"""Графический интерфейс журнала заявок."""

import sys
from pathlib import Path

from PySide6.QtCore import QLockFile, QRect, Qt
from PySide6.QtGui import QColor, QIcon, QPainter, QPen, QPixmap
from PySide6.QtWidgets import (
    QAbstractItemView,
    QApplication,
    QDialog,
    QFrame,
    QHeaderView,
    QHBoxLayout,
    QLabel,
    QMessageBox,
    QPlainTextEdit,
    QPushButton,
    QStyledItemDelegate,
    QStyleOptionViewItem,
    QTableWidget,
    QTableWidgetItem,
    QVBoxLayout,
    QWidget,
)

from journal import OPEN, Journal

APP_DIR = Path(__file__).resolve().parent


def journal_icon() -> QPixmap:
    icon = QPixmap(96, 96)
    icon.setDevicePixelRatio(2)
    icon.fill(Qt.GlobalColor.transparent)

    with QPainter(icon) as painter:
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        painter.setPen(Qt.PenStyle.NoPen)
        painter.setBrush(QColor("#a5f1de"))
        painter.drawRoundedRect(0, 0, 48, 48, 14, 14)

        pen = QPen(QColor("#103d38"), 2)
        pen.setCapStyle(Qt.PenCapStyle.RoundCap)
        painter.setPen(pen)
        painter.setBrush(Qt.BrushStyle.NoBrush)
        painter.drawRoundedRect(15, 12, 18, 24, 3, 3)
        for y in (19, 24, 29):
            painter.drawLine(20, y, 28, y)
    return icon


class StatusDelegate(QStyledItemDelegate):
    """Рисует статус цветной меткой, сохраняя его текст в таблице."""

    def paint(self, painter, option, index):
        style_option = QStyleOptionViewItem(option)
        self.initStyleOption(style_option, index)
        is_open = style_option.text == OPEN
        status = style_option.text
        style_option.text = ""
        widget = style_option.widget
        style = widget.style() if widget else QApplication.style()
        style.drawControl(style.ControlElement.CE_ItemViewItem, style_option, painter, widget)

        background, foreground = (
            ("#dff5ed", "#14604e") if is_open else ("#e8edf4", "#43546b")
        )
        painter.save()
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        font = style_option.font
        font.setPixelSize(13)
        font.setBold(True)
        painter.setFont(font)
        width = painter.fontMetrics().horizontalAdvance(status) + 34
        pill = QRect(option.rect.x() + 18, option.rect.center().y() - 13, width, 28)
        painter.setPen(Qt.PenStyle.NoPen)
        painter.setBrush(QColor(background))
        painter.drawRoundedRect(pill, 14, 14)
        painter.setBrush(QColor(foreground))
        painter.drawEllipse(pill.x() + 11, pill.y() + 11, 6, 6)
        painter.setPen(QColor(foreground))
        painter.drawText(
            pill.adjusted(23, 0, -10, 0),
            Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignVCenter,
            status,
        )
        painter.restore()


class AddTicketDialog(QDialog):
    def __init__(self, journal: Journal, parent: QWidget):
        super().__init__(parent)
        self.journal = journal
        self.ticket = None
        self.setWindowTitle("Новая заявка")
        self.setMinimumWidth(440)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(24, 22, 24, 22)
        layout.setSpacing(14)

        label = QLabel("Краткое описание проблемы")
        label.setObjectName("fieldLabel")
        self.description = QPlainTextEdit()
        self.description.setAccessibleName(label.text())
        self.description.setTabChangesFocus(True)
        self.description.setFixedHeight(114)
        layout.addWidget(label)
        layout.addWidget(self.description)

        buttons = QHBoxLayout()
        buttons.setSpacing(10)
        buttons.addStretch()
        cancel = QPushButton("Отмена")
        cancel.clicked.connect(self.reject)
        add = QPushButton("Добавить")
        add.setObjectName("primary")
        add.setEnabled(False)
        add.clicked.connect(self.save_ticket)
        self.description.textChanged.connect(
            lambda: add.setEnabled(bool(self.description.toPlainText().strip()))
        )
        buttons.addWidget(cancel)
        buttons.addWidget(add)
        layout.addLayout(buttons)
        self.description.setFocus()

    def save_ticket(self):
        try:
            self.ticket = self.journal.add(self.description.toPlainText())
        except (OSError, ValueError) as error:
            QMessageBox.warning(self, "Не удалось сохранить заявку", str(error))
            return
        self.accept()


class JournalWindow(QWidget):
    def __init__(self, journal: Journal):
        super().__init__()
        self.journal = journal
        self.setObjectName("window")
        self.setWindowTitle("Журнал заявок")
        self.resize(940, 626)
        self.setMinimumSize(680, 475)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)
        layout.addWidget(self.build_header())

        body = QVBoxLayout()
        body.setContentsMargins(28, 24, 28, 28)
        body.addWidget(self.build_list())
        layout.addLayout(body, 1)
        self.refresh_table()

    def build_header(self):
        header = QFrame()
        header.setObjectName("header")
        header.setFixedHeight(110)
        layout = QHBoxLayout(header)
        layout.setContentsMargins(28, 0, 28, 0)
        layout.setSpacing(14)

        icon = QLabel()
        icon.setPixmap(journal_icon())
        layout.addWidget(icon, 0, Qt.AlignmentFlag.AlignVCenter)

        title = QLabel("Журнал заявок")
        title.setObjectName("title")
        layout.addWidget(title)
        layout.addStretch()

        add = QPushButton("＋  Новая заявка")
        add.setAccessibleName("Новая заявка")
        add.setObjectName("primary")
        add.clicked.connect(self.add_ticket)
        layout.addWidget(add)
        return header

    def build_list(self):
        card = QFrame()
        card.setObjectName("card")
        layout = QVBoxLayout(card)
        layout.setContentsMargins(1, 1, 1, 1)
        layout.setSpacing(0)

        heading = QHBoxLayout()
        heading.setContentsMargins(20, 16, 20, 16)
        title = QLabel("Все заявки")
        title.setObjectName("sectionTitle")
        heading.addWidget(title)
        heading.addStretch()
        self.count = QLabel()
        self.count.setObjectName("count")
        heading.addWidget(self.count)
        layout.addLayout(heading)

        table = QTableWidget(0, 3)
        table.setAccessibleName("Список заявок")
        table.setHorizontalHeaderLabels(["Номер", "Описание", "Статус"])
        table.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        table.setSelectionMode(QAbstractItemView.SelectionMode.SingleSelection)
        table.setEditTriggers(QAbstractItemView.EditTrigger.NoEditTriggers)
        table.setShowGrid(False)
        table.setWordWrap(False)
        table.verticalHeader().hide()
        table.verticalHeader().setDefaultSectionSize(53)
        header = table.horizontalHeader()
        header.setDefaultAlignment(Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignVCenter)
        header.setFixedHeight(38)
        header.setSectionResizeMode(0, QHeaderView.ResizeMode.Fixed)
        header.setSectionResizeMode(1, QHeaderView.ResizeMode.Stretch)
        header.setSectionResizeMode(2, QHeaderView.ResizeMode.Fixed)
        table.setColumnWidth(0, 105)
        table.setColumnWidth(2, 146)
        table.setItemDelegateForColumn(2, StatusDelegate(table))
        table.itemSelectionChanged.connect(self.update_selection)
        self.table = table
        layout.addWidget(table, 1)

        footer = QFrame()
        footer.setObjectName("footer")
        actions = QHBoxLayout(footer)
        actions.setContentsMargins(20, 12, 20, 12)
        self.selection_label = QLabel()
        self.selection_label.setObjectName("selection")
        actions.addWidget(self.selection_label)
        actions.addStretch()
        self.close_button = QPushButton("Закрыть заявку")
        self.close_button.clicked.connect(self.close_ticket)
        actions.addWidget(self.close_button)
        layout.addWidget(footer)
        return card

    def refresh_table(self, selected_number=None):
        table = self.table
        table.clearSelection()
        table.setRowCount(len(self.journal.tickets))
        for row, ticket in enumerate(self.journal.tickets):
            number = QTableWidgetItem(f"№ {ticket.number:03}")
            description = QTableWidgetItem(" ".join(ticket.description.splitlines()))
            description.setToolTip(ticket.description)
            status = QTableWidgetItem(ticket.status)
            for column, item in enumerate((number, description, status)):
                table.setItem(row, column, item)
            if ticket.number == selected_number:
                table.selectRow(row)
                table.scrollToItem(number)
        self.count.setText(f"Всего {len(self.journal.tickets)}")
        self.update_selection()

    def selected_ticket(self):
        rows = self.table.selectionModel().selectedRows()
        return self.journal.tickets[rows[0].row()] if rows else None

    def update_selection(self):
        ticket = self.selected_ticket()
        self.close_button.setEnabled(ticket is not None and ticket.status == OPEN)
        self.selection_label.setText(
            f"Выбрана заявка № {ticket.number:03}" if ticket else "Выберите заявку в таблице"
        )

    def add_ticket(self):
        dialog = AddTicketDialog(self.journal, self)
        if dialog.exec() == QDialog.DialogCode.Accepted:
            self.refresh_table(dialog.ticket.number)
        dialog.deleteLater()

    def close_ticket(self):
        ticket = self.selected_ticket()
        if ticket is None or ticket.status != OPEN:
            return
        try:
            self.journal.close(ticket.number)
        except (OSError, ValueError) as error:
            QMessageBox.warning(self, "Не удалось закрыть заявку", str(error))
            return
        self.refresh_table(ticket.number)


def main():
    app = QApplication(sys.argv)
    app.setStyle("Fusion")
    app.setWindowIcon(QIcon(journal_icon()))
    app.setStyleSheet((APP_DIR / "style.qss").read_text(encoding="utf-8"))

    data_path = APP_DIR / "tickets.json"
    lock = QLockFile(str(data_path) + ".lock")
    lock.setStaleLockTime(0)
    if not lock.tryLock(0):
        QMessageBox.warning(
            None,
            "Не удалось открыть журнал",
            "Закройте другое окно журнала и проверьте права на запись в папку программы.",
        )
        return 1

    try:
        try:
            journal = Journal(data_path)
        except (OSError, ValueError) as error:
            QMessageBox.critical(None, "Не удалось загрузить заявки", str(error))
            return 1
        window = JournalWindow(journal)
        window.show()
        return app.exec()
    finally:
        lock.unlock()


if __name__ == "__main__":
    sys.exit(main())
