from sqlalchemy import Column, Integer, String, Float, DateTime
from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()

class Sales(Base):
    __tablename__ = 'sales'
    transaction_id = Column(Integer, primary_key=True)
    region = Column(String(50), nullable=False)
    amount = Column(Float, nullable=False)
    date = Column(DateTime, nullable=False)