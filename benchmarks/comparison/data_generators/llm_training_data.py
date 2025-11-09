"""
LLM Training Data Generator

Generates realistic large language model training metrics:
- Training loss curves with instabilities
- Perplexity metrics
- Token throughput
- Gradient statistics
- Hardware utilization (multi-GPU training)
- Checkpoint saves
- Evaluation metrics
"""

import random
import numpy as np
from datetime import datetime, timedelta
from typing import Iterator, List, Dict, Tuple, Optional
from dataclasses import dataclass
from enum import Enum
import math


class ModelSize(Enum):
    """LLM model sizes."""
    SMALL = "small"  # 125M - 350M params
    MEDIUM = "medium"  # 1B - 3B params
    LARGE = "large"  # 7B - 13B params
    XL = "xl"  # 30B - 70B params
    XXL = "xxl"  # 175B+ params


@dataclass
class TrainingStep:
    """Single training step metric."""
    time: datetime
    run_id: str
    step: int
    epoch: float
    model_size: str
    num_params_b: float  # Billions of parameters
    train_loss: float
    train_perplexity: float
    eval_loss: Optional[float]
    eval_perplexity: Optional[float]
    learning_rate: float
    gradient_norm: float
    tokens_per_second: float
    gpu_memory_used_gb: float
    num_gpus: int
    batch_size: int
    sequence_length: int
    has_divergence: bool


class LLMTrainingGenerator:
    """
    Generates realistic LLM training data.

    Features:
    - Multiple model sizes (125M - 175B+ params)
    - Realistic loss curves with training instabilities
    - Perplexity calculation (exp(loss))
    - Token throughput based on model size and hardware
    - Gradient statistics (norm, clipping)
    - Multi-GPU training simulation
    - Learning rate schedules (warmup + cosine decay)
    - Training instabilities (loss spikes, NaN, divergence)
    - Evaluation runs
    """

    def __init__(self, seed: int = 42):
        """Initialize generator with random seed."""
        random.seed(seed)
        np.random.seed(seed)

        # Model configurations
        self.model_configs = {
            ModelSize.SMALL: {
                "params_b": (0.125, 0.350),
                "initial_loss": (4.0, 6.0),
                "convergence_loss": (1.5, 2.5),
                "batch_size": [128, 256, 512],
                "num_gpus": [1, 2, 4],
                "tokens_per_sec_per_gpu": (5000, 10000)
            },
            ModelSize.MEDIUM: {
                "params_b": (1.0, 3.0),
                "initial_loss": (5.0, 7.0),
                "convergence_loss": (2.0, 3.0),
                "batch_size": [64, 128, 256],
                "num_gpus": [4, 8],
                "tokens_per_sec_per_gpu": (3000, 6000)
            },
            ModelSize.LARGE: {
                "params_b": (7.0, 13.0),
                "initial_loss": (6.0, 8.0),
                "convergence_loss": (2.5, 3.5),
                "batch_size": [32, 64, 128],
                "num_gpus": [8, 16, 32],
                "tokens_per_sec_per_gpu": (1000, 3000)
            },
            ModelSize.XL: {
                "params_b": (30.0, 70.0),
                "initial_loss": (7.0, 9.0),
                "convergence_loss": (2.8, 3.8),
                "batch_size": [16, 32, 64],
                "num_gpus": [32, 64, 128],
                "tokens_per_sec_per_gpu": (500, 1500)
            },
            ModelSize.XXL: {
                "params_b": (175.0, 500.0),
                "initial_loss": (8.0, 10.0),
                "convergence_loss": (3.0, 4.0),
                "batch_size": [8, 16, 32],
                "num_gpus": [128, 256, 512],
                "tokens_per_sec_per_gpu": (100, 500)
            }
        }

        self.run_counter = 0
        self.sequence_length = 2048  # Standard context window

        print(f"Initialized LLMTrainingGenerator")

    def _generate_run_id(self) -> str:
        """Generate unique run ID."""
        self.run_counter += 1
        return f"llm_run_{self.run_counter:08d}"

    def _select_model_size(self) -> str:
        """Select model size with realistic distribution."""
        # Smaller models more common
        sizes = list(ModelSize)
        weights = [0.35, 0.30, 0.20, 0.10, 0.05]
        return random.choices(sizes, weights=weights)[0].value

    def _generate_model_params(self, model_size: str) -> float:
        """Generate number of parameters (in billions)."""
        size_enum = ModelSize(model_size)
        config = self.model_configs[size_enum]
        params_range = config["params_b"]
        return round(random.uniform(*params_range), 2)

    def _calculate_loss(self, step: int, total_steps: int,
                       initial_loss: float, convergence_loss: float,
                       has_instability: bool = False) -> float:
        """
        Calculate training loss with realistic decay.

        Loss follows power law decay with noise and occasional spikes.
        """
        # Progress through training
        progress = step / total_steps

        # Power law decay (slower than exponential, more realistic for LLMs)
        alpha = 0.5  # Decay exponent
        loss = convergence_loss + (initial_loss - convergence_loss) * (1 - progress) ** alpha

        # Add noise (decreases with training)
        noise_scale = max(0.1 * (1 - progress * 0.8), 0.01)
        noise = np.random.normal(0, noise_scale)
        loss += noise

        # Training instabilities (loss spikes)
        if has_instability:
            if random.random() < 0.05:  # 5% chance of spike during instability
                spike_magnitude = random.uniform(1.5, 3.0)
                loss *= spike_magnitude

        # Occasional random spikes (even without instability period)
        if random.random() < 0.001:  # 0.1% chance
            loss *= random.uniform(1.3, 2.0)

        return max(loss, 0.1)

    def _calculate_perplexity(self, loss: float) -> float:
        """
        Calculate perplexity from loss.

        Perplexity = exp(loss)
        """
        # Clamp loss to prevent overflow
        loss = min(loss, 20.0)
        return math.exp(loss)

    def _calculate_learning_rate(self, step: int, total_steps: int,
                                 max_lr: float, warmup_steps: int) -> float:
        """
        Calculate learning rate with warmup + cosine decay schedule.

        Standard LLM training schedule:
        1. Linear warmup (0 → max_lr) for warmup_steps
        2. Cosine decay (max_lr → 0.1 * max_lr) for remaining steps
        """
        if step < warmup_steps:
            # Linear warmup
            return max_lr * (step / warmup_steps)
        else:
            # Cosine decay
            decay_steps = total_steps - warmup_steps
            progress = (step - warmup_steps) / decay_steps
            return max_lr * 0.5 * (1 + math.cos(math.pi * progress))

    def _calculate_gradient_norm(self, loss: float, step: int,
                                 has_instability: bool = False) -> float:
        """
        Calculate gradient norm.

        Higher early in training, decreases as model converges.
        Spikes during instabilities.
        """
        # Base gradient norm (proportional to loss)
        base_norm = loss * 2.0

        # Decay with training
        decay = math.exp(-step / 5000.0)

        # Add noise
        noise = np.random.lognormal(0, 0.3)

        gradient_norm = base_norm * decay * noise

        # Spike during instabilities
        if has_instability and random.random() < 0.1:
            gradient_norm *= random.uniform(3.0, 10.0)

        # Gradient clipping (typical threshold: 1.0)
        gradient_norm = min(gradient_norm, 10.0)

        return round(gradient_norm, 4)

    def _calculate_token_throughput(self, model_size: str, num_gpus: int,
                                    batch_size: int) -> float:
        """
        Calculate token throughput (tokens/sec).

        Depends on:
        - Model size (larger = slower)
        - Number of GPUs (more = faster, but sublinear scaling)
        - Batch size (larger = more efficient)
        """
        size_enum = ModelSize(model_size)
        config = self.model_configs[size_enum]

        # Base throughput per GPU
        tokens_per_sec_per_gpu = random.uniform(*config["tokens_per_sec_per_gpu"])

        # Multi-GPU scaling (80% efficiency)
        scaling_efficiency = 0.80
        total_throughput = tokens_per_sec_per_gpu * num_gpus * scaling_efficiency

        # Batch size efficiency (larger batches more efficient)
        batch_efficiency = 1.0 + math.log(batch_size / 32) * 0.1
        total_throughput *= batch_efficiency

        # Add variance
        total_throughput *= random.uniform(0.9, 1.1)

        return round(total_throughput, 2)

    def _calculate_gpu_memory(self, model_size: str, num_params_b: float,
                             batch_size: int, sequence_length: int) -> float:
        """
        Calculate GPU memory usage (GB).

        Memory = Model params + Optimizer states + Activations + Gradients
        """
        # Model parameters (FP16 = 2 bytes/param)
        model_memory = num_params_b * 2.0

        # Optimizer states (Adam = 8 bytes/param for momentum + variance)
        optimizer_memory = num_params_b * 8.0

        # Activations (depends on batch size and sequence length)
        # Rough estimate: batch_size * seq_length * hidden_dim * num_layers * bytes
        activation_memory = batch_size * sequence_length * num_params_b * 0.01

        # Gradients (same size as parameters)
        gradient_memory = num_params_b * 2.0

        total_memory = model_memory + optimizer_memory + activation_memory + gradient_memory

        # Add overhead (20%)
        total_memory *= 1.2

        # Add variance
        total_memory *= random.uniform(0.9, 1.1)

        return round(total_memory, 2)

    def _should_have_instability_period(self) -> bool:
        """Determine if training run has instability period (20% chance)."""
        return random.random() < 0.20

    def _generate_training_run(self, current_time: datetime) -> List[TrainingStep]:
        """
        Generate complete LLM training run.

        Returns:
            List of TrainingStep objects
        """
        steps = []

        # Initialize run
        run_id = self._generate_run_id()

        # Select model configuration
        model_size = self._select_model_size()
        size_enum = ModelSize(model_size)
        config = self.model_configs[size_enum]

        num_params_b = self._generate_model_params(model_size)
        initial_loss = random.uniform(*config["initial_loss"])
        convergence_loss = random.uniform(*config["convergence_loss"])
        batch_size = random.choice(config["batch_size"])
        num_gpus = random.choice(config["num_gpus"])

        # Training configuration
        total_steps = random.randint(50000, 500000)
        warmup_steps = int(total_steps * 0.03)  # 3% warmup
        max_lr = random.choice([0.0001, 0.0003, 0.0006, 0.001])

        # Log every N steps
        log_frequency = random.choice([100, 500, 1000])

        # Evaluation every N steps
        eval_frequency = log_frequency * 10

        # Check if training has instability period
        has_instability = self._should_have_instability_period()
        if has_instability:
            instability_start = random.randint(1000, total_steps // 2)
            instability_end = instability_start + random.randint(1000, 5000)
        else:
            instability_start = instability_end = -1

        run_time = current_time

        for step in range(0, total_steps, log_frequency):
            # Check if in instability period
            in_instability = has_instability and instability_start <= step < instability_end

            # Calculate metrics
            learning_rate = self._calculate_learning_rate(step, total_steps, max_lr, warmup_steps)
            train_loss = self._calculate_loss(step, total_steps, initial_loss,
                                             convergence_loss, in_instability)
            train_perplexity = self._calculate_perplexity(train_loss)
            gradient_norm = self._calculate_gradient_norm(train_loss, step, in_instability)
            tokens_per_sec = self._calculate_token_throughput(model_size, num_gpus, batch_size)
            gpu_memory = self._calculate_gpu_memory(model_size, num_params_b,
                                                    batch_size, self.sequence_length)

            # Evaluation metrics (only every eval_frequency steps)
            if step % eval_frequency == 0:
                eval_loss = self._calculate_loss(step, total_steps, initial_loss,
                                                convergence_loss * 1.1, in_instability)
                eval_perplexity = self._calculate_perplexity(eval_loss)
            else:
                eval_loss = None
                eval_perplexity = None

            # Check for divergence (loss > 2x initial loss)
            has_divergence = train_loss > (initial_loss * 2.0)

            # Calculate epoch (tokens processed / dataset size)
            # Assume dataset size: 100B tokens
            dataset_size_tokens = 100_000_000_000
            tokens_per_step = batch_size * self.sequence_length * num_gpus
            total_tokens = step * tokens_per_step
            epoch = total_tokens / dataset_size_tokens

            steps.append(TrainingStep(
                time=run_time,
                run_id=run_id,
                step=step,
                epoch=round(epoch, 4),
                model_size=model_size,
                num_params_b=num_params_b,
                train_loss=round(train_loss, 4),
                train_perplexity=round(train_perplexity, 4),
                eval_loss=round(eval_loss, 4) if eval_loss else None,
                eval_perplexity=round(eval_perplexity, 4) if eval_perplexity else None,
                learning_rate=learning_rate,
                gradient_norm=gradient_norm,
                tokens_per_second=tokens_per_sec,
                gpu_memory_used_gb=gpu_memory,
                num_gpus=num_gpus,
                batch_size=batch_size,
                sequence_length=self.sequence_length,
                has_divergence=has_divergence
            ))

            # Increment time (each step takes 1-10 seconds depending on model size)
            step_duration = random.uniform(1.0, 10.0) * (num_params_b / 10.0)
            run_time += timedelta(seconds=step_duration)

        return steps

    def generate_training_data(self, num_runs: int = 100) -> Iterator[TrainingStep]:
        """
        Generate LLM training data for multiple runs.

        Args:
            num_runs: Number of training runs

        Yields:
            TrainingStep objects
        """
        start_time = datetime.now()

        print(f"Generating {num_runs:,} LLM training runs...")

        steps_generated = 0
        current_time = start_time

        for run_num in range(num_runs):
            # Generate complete training run
            run_steps = self._generate_training_run(current_time)

            for step in run_steps:
                yield step
                steps_generated += 1

            # Move time forward for next run
            current_time += timedelta(hours=random.randint(6, 48))

            # Progress update
            if (run_num + 1) % 10 == 0:
                print(f"  Generated {run_num + 1:,} runs ({steps_generated:,} steps)...")

        print(f"✅ Generated {steps_generated:,} training steps from {num_runs:,} runs")
        print(f"   Avg {steps_generated/num_runs:.0f} steps per run")

    def generate_dataset(self, size: str = "small") -> List[TrainingStep]:
        """
        Generate complete dataset.

        Args:
            size: 'small' (1M rows), 'medium' (100M rows), 'large' (1B rows)

        Returns:
            List of TrainingStep objects
        """
        # Calculate parameters based on size
        # Avg ~10K steps per run
        if size == "small":
            num_runs = 100
        elif size == "medium":
            num_runs = 10000
        elif size == "large":
            num_runs = 100000
        else:
            raise ValueError(f"Unknown size: {size}")

        data = list(self.generate_training_data(num_runs=num_runs))

        return data


def main():
    """Example usage and testing."""
    generator = LLMTrainingGenerator(seed=42)

    # Generate 5 training runs
    print("\nGenerating sample LLM training data...")
    steps = list(generator.generate_training_data(num_runs=5))

    print(f"\n✅ Generated {len(steps):,} training steps")
    print("\nSample steps (first 20):")

    for i, step in enumerate(steps[:20]):
        eval_str = f"eval_loss={step.eval_loss:.3f}" if step.eval_loss else ""
        div_str = "🔴 DIVERGED" if step.has_divergence else ""

        print(f"  {i+1}. {step.time.strftime('%H:%M:%S')} | {step.run_id} | "
              f"Step {step.step:6d} | {step.model_size:6s} {step.num_params_b:6.2f}B | "
              f"loss={step.train_loss:.3f} ppl={step.train_perplexity:7.2f} | "
              f"LR={step.learning_rate:.6f} | {eval_str:18s} {div_str}")

    # Statistics
    from collections import Counter

    print("\nModel Size Distribution:")
    size_counts = Counter(s.model_size for s in steps)
    for size, count in size_counts.most_common():
        print(f"  {size:10s}: {count:5d} ({count/len(steps)*100:5.1f}%)")

    print("\nLoss Statistics:")
    train_losses = [s.train_loss for s in steps]
    print(f"  Min: {min(train_losses):.3f}")
    print(f"  p50: {np.percentile(train_losses, 50):.3f}")
    print(f"  p95: {np.percentile(train_losses, 95):.3f}")
    print(f"  Max: {max(train_losses):.3f}")

    print("\nPerplexity Statistics:")
    perplexities = [s.train_perplexity for s in steps]
    print(f"  Min: {min(perplexities):.2f}")
    print(f"  p50: {np.percentile(perplexities, 50):.2f}")
    print(f"  p95: {np.percentile(perplexities, 95):.2f}")
    print(f"  Max: {max(perplexities):.2f}")

    print("\nThroughput Statistics:")
    throughputs = [s.tokens_per_second for s in steps]
    print(f"  Avg throughput: {np.mean(throughputs):,.0f} tokens/sec")
    print(f"  Min: {min(throughputs):,.0f} tokens/sec")
    print(f"  Max: {max(throughputs):,.0f} tokens/sec")

    print("\nGPU Memory Statistics:")
    memories = [s.gpu_memory_used_gb for s in steps]
    print(f"  Avg memory: {np.mean(memories):.1f} GB")
    print(f"  Max memory: {max(memories):.1f} GB")

    print("\nTraining Instabilities:")
    diverged_steps = [s for s in steps if s.has_divergence]
    print(f"  Diverged steps: {len(diverged_steps)} ({len(diverged_steps)/len(steps)*100:.2f}%)")

    # Analyze convergence
    print("\nConvergence Analysis (per run):")
    runs = {}
    for step in steps:
        if step.run_id not in runs:
            runs[step.run_id] = []
        runs[step.run_id].append(step)

    for run_id, run_steps in list(runs.items())[:3]:
        run_steps.sort(key=lambda x: x.step)
        initial_loss = run_steps[0].train_loss
        final_loss = run_steps[-1].train_loss
        improvement = (initial_loss - final_loss) / initial_loss * 100

        print(f"  {run_id}: {initial_loss:.3f} → {final_loss:.3f} "
              f"({improvement:.1f}% improvement, {len(run_steps)} steps)")


if __name__ == "__main__":
    main()
