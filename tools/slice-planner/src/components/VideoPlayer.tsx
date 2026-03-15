import { useState, useRef, useEffect, useCallback } from 'react'
import type { StepTiming } from '../api/client'
import { reportArtifactUrl } from '../api/client'

interface VideoPlayerProps {
  sliceName: string;
  videoPath?: string;
  stepTimings: StepTiming[];
  videoOffsetSeconds: number;
}

export default function VideoPlayer({ sliceName, videoPath, stepTimings, videoOffsetSeconds }: VideoPlayerProps) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const [activeStep, setActiveStep] = useState<number>(-1);
  const [videoError, setVideoError] = useState(false);

  const updateActiveStep = useCallback(() => {
    const video = videoRef.current;
    if (!video) return;
    const t = video.currentTime - videoOffsetSeconds;
    let found = -1;
    for (let i = 0; i < stepTimings.length; i++) {
      const s = stepTimings[i];
      if (t >= s.start_seconds && t < s.start_seconds + s.duration_seconds) {
        found = i;
        break;
      }
    }
    setActiveStep(prev => prev === found ? prev : found);
  }, [stepTimings, videoOffsetSeconds]);

  useEffect(() => {
    const video = videoRef.current;
    if (!video) return;
    video.addEventListener('timeupdate', updateActiveStep);
    return () => video.removeEventListener('timeupdate', updateActiveStep);
  }, [updateActiveStep]);

  const seekToStep = (step: StepTiming) => {
    const video = videoRef.current;
    if (!video) return;
    video.currentTime = step.start_seconds + videoOffsetSeconds;
    video.play().catch(() => { /* autoplay blocked */ });
  };

  const formatTime = (seconds: number) => {
    const m = Math.floor(seconds / 60);
    const s = Math.floor(seconds % 60);
    return `${m}:${s.toString().padStart(2, '0')}`;
  };

  if (!videoPath) {
    return <div className="video-unavailable">No video available</div>;
  }

  const videoUrl = reportArtifactUrl(sliceName, videoPath);

  return (
    <div className="video-player">
      {videoError ? (
        <div className="video-unavailable">No video available</div>
      ) : (
        <video
          ref={videoRef}
          className="video-element"
          controls
          preload="metadata"
          onError={() => setVideoError(true)}
        >
          <source src={videoUrl} type="video/mp4" />
        </video>
      )}

      {stepTimings.length > 0 && (
        <div className="step-list">
          {stepTimings.map((step, i) => (
            <button
              key={i}
              className={`step-item ${activeStep === i ? 'step-active' : ''}`}
              onClick={() => seekToStep(step)}
            >
              <span className="step-time">{formatTime(step.start_seconds)}</span>
              <span className="step-name">{step.step}</span>
              <span className="step-duration">{step.duration_seconds.toFixed(1)}s</span>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
