from elasticsearch import helpers
import annotator.reindexer

from h.models import Annotation, Document, ANALYSIS


class Reindexer(annotator.reindexer.Reindexer):
    es_models = Annotation, Document
    analysis_settings = ANALYSIS
