"""
Deep Learning Experiment Tracking Data Generator

Generates realistic ML/DL training experiment data:
- Training metrics (loss, accuracy, validation metrics)
- Hyperparameters (learning rate, batch size, optimizer)
- Model architectures (CNNs, Transformers, etc.)
- Dataset configurations
- Hardware specifications
- Experiment versioning
"""

import random
import numpy as np
from datetime import datetime, timedelta
from typing import Iterator, List, Dict, Tuple, Optional
from dataclasses import dataclass
from enum import Enum
import math


class ModelType(Enum):
    """Types of deep learning models."""
    CNN = "cnn"
    RESNET = "resnet"
    VGG = "vgg"
    TRANSFORMER = "transformer"
    BERT = "bert"
    GPT = "gpt"
    LSTM = "lstm"
    GAN = "gan"


class OptimizerType(Enum):
    """Optimizer types."""
    SGD = "sgd"
    ADAM = "adam"
    ADAMW = "adamw"
    RMSPROP = "rmsprop"
    ADAGRAD = "adagrad"


@dataclass
class TrainingMetric:
    """Single training metric record."""
    time: datetime
    experiment_id: str
    run_id: int
    epoch: int
    step: int
    model_type: str
    optimizer: str
    learning_rate: float
    batch_size: int
    train_loss: float
    train_accuracy: Optional[float]
    val_loss: Optional[float]
    val_accuracy: Optional[float]
    learning_rate_current: float  # After scheduler
    gradient_norm: float
    gpu_utilization: float  # 0-100%
    memory_used_gb: float


class DLExperimentGenerator:
    """
    Generates realistic deep learning training experiment data.

    Features:
    - Multiple model architectures (CNNs, Transformers, etc.)
    - Realistic loss curves (exponential decay with noise)
    - Learning rate schedules (cosine annealing, step decay)
    - Hyperparameter configurations
    - Validation metrics
    - Hardware metrics (GPU utilization, memory)
    - Training instabilities (spikes, divergence)
    - Overfitting patterns
    """

    def __init__(self, seed: int = 42):
        """Initialize generator with random seed."""
        random.seed(seed)
        np.random.seed(seed)

        # Model configurations
        self.model_configs = {
            ModelType.CNN: {
                "typical_batch_size": [32, 64, 128, 256],
                "typical_lr": [0.001, 0.01, 0.1],
                "typical_epochs": (10, 100),
                "initial_loss": (2.5, 5.0),
                "convergence_loss": (0.1, 0.5)
            },
            ModelType.RESNET: {
                "typical_batch_size": [64, 128, 256],
                "typical_lr": [0.0001, 0.001, 0.01],
                "typical_epochs": (50, 200),
                "initial_loss": (3.0, 6.0),
                "convergence_loss": (0.05, 0.3)
            },
            ModelType.TRANSFORMER: {
                "typical_batch_size": [16, 32, 64],
                "typical_lr": [0.0001, 0.0005, 0.001],
                "typical_epochs": (10, 50),
                "initial_loss": (5.0, 10.0),
                "convergence_loss": (0.5, 2.0)
            },
            ModelType.BERT: {
                "typical_batch_size": [8, 16, 32],
                "typical_lr": [0.00001, 0.00005, 0.0001],
                "typical_epochs": (3, 10),
                "initial_loss": (4.0, 8.0),
                "convergence_loss": (0.2, 1.0)
            },
            ModelType.GPT: {
                "typical_batch_size": [4, 8, 16],
                "typical_lr": [0.0001, 0.0005, 0.001],
                "typical_epochs": (5, 20),
                "initial_loss": (6.0, 12.0),
                "convergence_loss": (1.0, 3.0)
            }
        }

        # Optimizers with typical configurations
        self.optimizers = {
            OptimizerType.SGD: {"momentum": [0.0, 0.9, 0.95]},
            OptimizerType.ADAM: {"beta1": [0.9], "beta2": [0.999]},
            OptimizerType.ADAMW: {"beta1": [0.9], "beta2": [0.999], "weight_decay": [0.01, 0.001]},
        }

        # Hardware specs
        self.gpu_types = ["V100", "A100", "RTX3090", "RTX4090", "H100"]
        self.gpu_memory = {
            "V100": 16,
            "A100": 40,
            "RTX3090": 24,
            "RTX4090": 24,
            "H100": 80
        }

        self.experiment_counter = 0
        self.run_counter = 0

        print(f"Initialized DLExperimentGenerator")

    def _generate_experiment_id(self) -> str:
        """Generate unique experiment ID."""
        self.experiment_counter += 1
        return f"exp_{self.experiment_counter:08d}"

    def _generate_run_id(self) -> int:
        """Generate unique run ID."""
        self.run_counter += 1
        return self.run_counter

    def _select_model_type(self) -> str:
        """Select model type with realistic distribution."""
        # ResNet and CNNs most common, Transformers growing
        model_types = list(ModelType)
        weights = [0.25, 0.30, 0.10, 0.15, 0.08, 0.07, 0.05, 0.0]  # GAN disabled for simplicity
        return random.choices(model_types, weights=weights)[0].value

    def _select_optimizer(self) -> str:
        """Select optimizer with realistic distribution."""
        # Adam/AdamW most popular
        optimizers = list(OptimizerType)
        weights = [0.15, 0.45, 0.30, 0.08, 0.02]
        return random.choices(optimizers, weights=weights)[0].value

    def _generate_hyperparameters(self, model_type: str) -> Dict:
        """Generate hyperparameters for model type."""
        # Get model config
        model_enum = ModelType(model_type)
        config = self.model_configs.get(model_enum, self.model_configs[ModelType.CNN])

        # Select hyperparameters
        batch_size = random.choice(config["typical_batch_size"])
        learning_rate = random.choice(config["typical_lr"])
        num_epochs = random.randint(*config["typical_epochs"])
        initial_loss_range = config["initial_loss"]
        convergence_loss_range = config["convergence_loss"]

        return {
            "batch_size": batch_size,
            "learning_rate": learning_rate,
            "num_epochs": num_epochs,
            "initial_loss": random.uniform(*initial_loss_range),
            "convergence_loss": random.uniform(*convergence_loss_range)
        }

    def _calculate_loss(self, epoch: int, step: int, total_epochs: int,
                       initial_loss: float, convergence_loss: float,
                       is_validation: bool = False) -> float:
        """
        Calculate training loss with realistic decay pattern.

        Uses exponential decay with noise:
        loss(t) = convergence + (initial - convergence) * exp(-decay_rate * t) + noise
        """
        # Progress through training (0 to 1)
        progress = (epoch + step / 100.0) / total_epochs

        # Exponential decay
        decay_rate = 3.0  # Controls how fast loss decreases
        loss = convergence_loss + (initial_loss - convergence_loss) * np.exp(-decay_rate * progress)

        # Add noise (larger early in training)
        noise_scale = max(0.1 * (1 - progress * 0.7), 0.01)  # Noise decreases as training progresses
        noise = np.random.normal(0, noise_scale)
        loss += noise

        # Validation loss slightly higher than training (overfitting)
        if is_validation:
            overfitting_gap = 0.1 + progress * 0.3  # Gap increases with training
            loss += overfitting_gap

        # Random spikes (training instability)
        if random.random() < 0.01:  # 1% chance
            loss *= random.uniform(1.5, 3.0)

        return max(loss, 0.01)

    def _calculate_accuracy(self, loss: float, is_classification: bool = True) -> Optional[float]:
        """
        Calculate accuracy from loss (inverse relationship).

        Lower loss → higher accuracy.
        """
        if not is_classification:
            return None

        # Rough mapping: loss 0.1 → acc 0.95, loss 1.0 → acc 0.7, loss 5.0 → acc 0.2
        # Use sigmoid-like function
        accuracy = 1.0 / (1.0 + loss * 2.0)

        # Add noise
        accuracy += np.random.normal(0, 0.02)

        return max(min(accuracy, 1.0), 0.0)

    def _calculate_learning_rate(self, epoch: int, step: int, initial_lr: float,
                                 total_epochs: int, schedule: str = "cosine") -> float:
        """
        Calculate learning rate with scheduler.

        Schedules:
        - cosine: Cosine annealing
        - step: Step decay (divide by 10 every N epochs)
        - constant: No schedule
        """
        if schedule == "constant":
            return initial_lr
        elif schedule == "step":
            # Divide by 10 every 30 epochs
            decay_epochs = 30
            decay_factor = 0.1
            num_decays = epoch // decay_epochs
            return initial_lr * (decay_factor ** num_decays)
        else:  # cosine
            # Cosine annealing
            progress = (epoch + step / 100.0) / total_epochs
            return initial_lr * 0.5 * (1 + np.cos(np.pi * progress))

    def _calculate_gradient_norm(self, loss: float, epoch: int) -> float:
        """
        Calculate gradient norm (related to loss and training stage).

        High early in training, decreases as model converges.
        """
        # Base gradient norm
        base_norm = loss * 2.0

        # Decrease with training
        decay = np.exp(-epoch / 20.0)

        # Add noise
        noise = np.random.lognormal(0, 0.3)

        return base_norm * decay * noise

    def _calculate_gpu_metrics(self, batch_size: int, model_type: str) -> Tuple[float, float]:
        """
        Calculate GPU utilization and memory usage.

        Args:
            batch_size: Batch size
            model_type: Model type

        Returns:
            (utilization %, memory GB)
        """
        # Utilization (70-100% during training)
        utilization = random.uniform(70, 100)

        # Memory usage depends on model and batch size
        base_memory = {
            "cnn": 2.0,
            "resnet": 4.0,
            "vgg": 6.0,
            "transformer": 8.0,
            "bert": 12.0,
            "gpt": 16.0,
            "lstm": 3.0,
            "gan": 10.0
        }

        memory = base_memory.get(model_type, 5.0)
        # Scale with batch size
        memory *= (batch_size / 32.0)
        # Add variance
        memory *= random.uniform(0.8, 1.2)

        return (utilization, memory)

    def _generate_training_run(self, current_time: datetime) -> List[TrainingMetric]:
        """
        Generate complete training run (all epochs).

        Returns:
            List of TrainingMetric objects
        """
        metrics = []

        # Initialize experiment
        experiment_id = self._generate_experiment_id()
        run_id = self._generate_run_id()

        # Select model and optimizer
        model_type = self._select_model_type()
        optimizer = self._select_optimizer()

        # Generate hyperparameters
        hyperparams = self._generate_hyperparameters(model_type)
        batch_size = hyperparams["batch_size"]
        learning_rate = hyperparams["learning_rate"]
        num_epochs = hyperparams["num_epochs"]
        initial_loss = hyperparams["initial_loss"]
        convergence_loss = hyperparams["convergence_loss"]

        # Select LR schedule
        lr_schedule = random.choice(["cosine", "step", "constant"])

        # Is this a classification task?
        is_classification = random.random() < 0.7  # 70% classification, 30% regression

        # Training loop
        run_time = current_time

        for epoch in range(num_epochs):
            # Steps per epoch (typically 100-1000)
            steps_per_epoch = random.randint(100, 1000)

            # Log every N steps
            log_frequency = random.choice([10, 20, 50, 100])

            for step in range(0, steps_per_epoch, log_frequency):
                # Calculate current LR
                current_lr = self._calculate_learning_rate(
                    epoch, step, learning_rate, num_epochs, lr_schedule
                )

                # Calculate training metrics
                train_loss = self._calculate_loss(
                    epoch, step, num_epochs, initial_loss, convergence_loss, is_validation=False
                )
                train_accuracy = self._calculate_accuracy(train_loss, is_classification)

                # Calculate validation metrics (only every few steps)
                if step % (log_frequency * 5) == 0:
                    val_loss = self._calculate_loss(
                        epoch, step, num_epochs, initial_loss, convergence_loss, is_validation=True
                    )
                    val_accuracy = self._calculate_accuracy(val_loss, is_classification)
                else:
                    val_loss = None
                    val_accuracy = None

                # Calculate gradient norm
                gradient_norm = self._calculate_gradient_norm(train_loss, epoch)

                # Calculate GPU metrics
                gpu_util, gpu_memory = self._calculate_gpu_metrics(batch_size, model_type)

                # Create metric record
                metrics.append(TrainingMetric(
                    time=run_time,
                    experiment_id=experiment_id,
                    run_id=run_id,
                    epoch=epoch,
                    step=step,
                    model_type=model_type,
                    optimizer=optimizer,
                    learning_rate=learning_rate,
                    batch_size=batch_size,
                    train_loss=train_loss,
                    train_accuracy=train_accuracy,
                    val_loss=val_loss,
                    val_accuracy=val_accuracy,
                    learning_rate_current=current_lr,
                    gradient_norm=gradient_norm,
                    gpu_utilization=gpu_util,
                    memory_used_gb=gpu_memory
                ))

                # Increment time (each step takes 0.5-2 seconds)
                run_time += timedelta(seconds=random.uniform(0.5, 2.0))

        return metrics

    def generate_metrics(self, num_experiments: int = 1000) -> Iterator[TrainingMetric]:
        """
        Generate training metrics for multiple experiments.

        Args:
            num_experiments: Number of training experiments to generate

        Yields:
            TrainingMetric objects
        """
        start_time = datetime.now()

        print(f"Generating {num_experiments:,} training experiments...")

        metrics_generated = 0
        current_time = start_time

        for exp_num in range(num_experiments):
            # Generate complete training run
            run_metrics = self._generate_training_run(current_time)

            for metric in run_metrics:
                yield metric
                metrics_generated += 1

            # Move time forward for next experiment
            current_time += timedelta(hours=random.randint(1, 24))

            # Progress update
            if (exp_num + 1) % 100 == 0:
                print(f"  Generated {exp_num + 1:,} experiments ({metrics_generated:,} metrics)...")

        print(f"✅ Generated {metrics_generated:,} metrics from {num_experiments:,} experiments")
        print(f"   Avg {metrics_generated/num_experiments:.1f} metrics per experiment")

    def generate_dataset(self, size: str = "small") -> List[TrainingMetric]:
        """
        Generate complete dataset.

        Args:
            size: 'small' (1M rows), 'medium' (100M rows), 'large' (1B rows)

        Returns:
            List of TrainingMetric objects
        """
        # Calculate parameters based on size
        # Avg ~1000 metrics per experiment
        if size == "small":
            # 1M metrics ≈ 1K experiments
            num_experiments = 1000
        elif size == "medium":
            # 100M metrics ≈ 100K experiments
            num_experiments = 100000
        elif size == "large":
            # 1B metrics ≈ 1M experiments
            num_experiments = 1000000
        else:
            raise ValueError(f"Unknown size: {size}")

        metrics = list(self.generate_metrics(num_experiments=num_experiments))

        return metrics


def main():
    """Example usage and testing."""
    generator = DLExperimentGenerator(seed=42)

    # Generate 10 experiments
    print("\nGenerating sample DL experiment data...")
    metrics = list(generator.generate_metrics(num_experiments=10))

    print(f"\n✅ Generated {len(metrics):,} metrics")
    print("\nSample metrics (first 20):")

    for i, metric in enumerate(metrics[:20]):
        val_str = f"val_loss={metric.val_loss:.3f}" if metric.val_loss else ""
        acc_str = f"acc={metric.train_accuracy:.3f}" if metric.train_accuracy else ""

        print(f"  {i+1}. {metric.time.strftime('%H:%M:%S')} | "
              f"{metric.experiment_id} | E{metric.epoch:02d} S{metric.step:04d} | "
              f"{metric.model_type:12s} | loss={metric.train_loss:.3f} {acc_str:12s} | "
              f"LR={metric.learning_rate_current:.6f} | {val_str}")

    # Statistics
    print("\nModel Type Distribution:")
    from collections import Counter
    model_counts = Counter(m.model_type for m in metrics)
    for model, count in model_counts.most_common():
        print(f"  {model:15s}: {count:5d} ({count/len(metrics)*100:5.1f}%)")

    print("\nOptimizer Distribution:")
    optimizer_counts = Counter(m.optimizer for m in metrics)
    for optimizer, count in optimizer_counts.most_common():
        print(f"  {optimizer:10s}: {count:5d} ({count/len(metrics)*100:5.1f}%)")

    print("\nLoss Statistics:")
    train_losses = [m.train_loss for m in metrics]
    print(f"  Min: {min(train_losses):.3f}")
    print(f"  p25: {np.percentile(train_losses, 25):.3f}")
    print(f"  p50: {np.percentile(train_losses, 50):.3f}")
    print(f"  p75: {np.percentile(train_losses, 75):.3f}")
    print(f"  Max: {max(train_losses):.3f}")

    print("\nValidation Metrics:")
    val_metrics = [m for m in metrics if m.val_loss is not None]
    if val_metrics:
        print(f"  Validation samples: {len(val_metrics)}")
        val_losses = [m.val_loss for m in val_metrics]
        print(f"  Avg val loss: {np.mean(val_losses):.3f}")
        print(f"  Overfitting gap: {np.mean([m.val_loss - m.train_loss for m in val_metrics]):.3f}")

    print("\nHardware Utilization:")
    print(f"  Avg GPU util: {np.mean([m.gpu_utilization for m in metrics]):.1f}%")
    print(f"  Avg GPU memory: {np.mean([m.memory_used_gb for m in metrics]):.1f} GB")

    print("\nExperiment Summary:")
    experiments = set(m.experiment_id for m in metrics)
    print(f"  Total experiments: {len(experiments)}")
    print(f"  Metrics per experiment: {len(metrics) / len(experiments):.0f}")

    # Analyze convergence
    print("\nConvergence Analysis:")
    for exp_id in list(experiments)[:3]:  # First 3 experiments
        exp_metrics = [m for m in metrics if m.experiment_id == exp_id]
        exp_metrics.sort(key=lambda x: (x.epoch, x.step))

        initial_loss = exp_metrics[0].train_loss
        final_loss = exp_metrics[-1].train_loss
        improvement = (initial_loss - final_loss) / initial_loss * 100

        print(f"  {exp_id}: {initial_loss:.3f} → {final_loss:.3f} ({improvement:.1f}% improvement)")


if __name__ == "__main__":
    main()
