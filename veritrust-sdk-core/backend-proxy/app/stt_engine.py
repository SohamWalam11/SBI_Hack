import os
import whisper
import logging
import tempfile
from fastapi import UploadFile

logger = logging.getLogger("veritrust.stt")

# Ensure the locally downloaded ffmpeg is in PATH
current_dir = os.getcwd()
if current_dir not in os.environ.get("PATH", ""):
    os.environ["PATH"] += os.pathsep + current_dir

_model = None

def get_whisper_model():
    global _model
    if _model is None:
        logger.info("Loading OpenAI Whisper 'base' model for STT...")
        # 'base' handles multiple languages reasonably well and runs fast on CPU
        _model = whisper.load_model("base")
        logger.info("Whisper model loaded.")
    return _model

async def transcribe_audio(file: UploadFile) -> str:
    """Transcribes an uploaded audio file using Whisper."""
    model = get_whisper_model()
    
    # Save the upload to a temporary file
    with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as temp_audio:
        temp_audio.write(await file.read())
        temp_audio_path = temp_audio.name
        
    try:
        # Transcribe with automatic language detection
        result = model.transcribe(temp_audio_path)
        text = result["text"].strip()
        lang = result.get('language', 'unknown')
        logger.info(f"Transcription complete. Detected language: {lang}. Text: {text}")
        return text
    finally:
        if os.path.exists(temp_audio_path):
            try:
                os.remove(temp_audio_path)
            except Exception as e:
                logger.error(f"Failed to cleanup temp audio file: {e}")
