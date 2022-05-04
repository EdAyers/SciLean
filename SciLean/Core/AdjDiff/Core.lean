import SciLean.Core.Diff
import SciLean.Core.Adjoint
import SciLean.Core.HasAdjDiff

namespace SciLean


variable {α β γ : Type}
variable {X Y Z : Type} [SemiHilbert X] [SemiHilbert Y] [SemiHilbert Z] 
variable {Y₁ Y₂ : Type} [SemiHilbert Y₁] [SemiHilbert Y₂]
variable {ι : Type} [Enumtype ι]


noncomputable 
def adjDiff
  (f : X → Y) (x : X) : Y → X := (δ f x)†

prefix:max "δ†" => adjDiff
macro:max "∇" f:term:max : term => `(λ x => δ† $f x (1:ℝ))


----------------------------------------------------------------------


@[simp]
theorem id.arg_x.adjDiff_simp
  : δ† (λ x : X => x) = λ x dx => dx := by simp[adjDiff] done

@[simp]
theorem const.arg_x.adjDiff_simp 
  : δ† (λ (x : X) (i : ι) => x) = λ x f => ∑ i, f i := by simp[adjDiff] done

@[simp]
theorem const.arg_y.adjDiff_simp (x : X)
  : δ† (λ (y : Y) => x) = (λ y dy' => (0 : Y)) := by simp[adjDiff] done

@[simp low-3]
theorem swap.arg_y.adjDiff_simp
  (f : ι → Y → Z) [∀ i, IsSmooth (f i)] [∀ i x, HasAdjoint $ δ (f i) x]
  : δ† (λ y i => f i y) = (λ y dy' => ∑ i, (δ† (f i) y) (dy' i)) := 
by 
  simp[adjDiff] done

@[simp low-1]
theorem comp.arg_x.adjDiff_simp
  (f : Y → Z) [IsSmooth f] [∀ y, HasAdjoint $ δ f y] 
  (g : X → Y) [IsSmooth g] [∀ x, HasAdjoint $ δ g x] 
  : δ† (λ x => f (g x)) = λ x dx' => (δ† g x) ((δ† f (g x)) dx') := 
by 
  simp[adjDiff] done


@[simp low-2]
theorem diag.arg_x.adjDiff_simp
  (f : Y₁ → Y₂ → Z) [IsSmooth f] [∀ y₁, IsSmooth (f y₁)] 
  [∀ y₁ y₂, HasAdjoint (λ dy₁ => δ f y₁ dy₁ y₂)]
  [∀ y₁ y₂, HasAdjoint (λ dy₂ => δ (f y₁) y₂ dy₂)]
  (g₁ : X → Y₁) [IsSmooth g₁] [∀ x, HasAdjoint (δ g₁ x)]
  (g₂ : X → Y₂) [IsSmooth g₂] [∀ x, HasAdjoint (δ g₂ x)]
  : δ† (λ x => f (g₁ x) (g₂ x)) 
    = 
    λ x dx' => 
      (δ† g₁ x) ((δ† λ y₁ => f y₁ (g₂ x)) (g₁ x) dx')
      +
      (δ† g₂ x) ((δ† λ y₂ => f (g₁ x) y₂) (g₂ x) dx')
    := 
by 
  have inst : HasAdjoint (λ yy : Z × Z => yy.1 + yy.2) := sorry
  simp[adjDiff] admit

-- @[simp low]
-- theorem parm.arg_x.adjDiff_simp
--   (f : X → ι → Z) [∀ x, HasAdjoint $ δ f x] (i : ι)
--   : (λ x => f x i)† = (λ x' => f† (λ j => (kron i j) * x'))
-- := sorry

@[simp low]
theorem eval.arg_f.adjDiff_simp
  (i : ι)
  : δ† (λ (f : ι → X) => f i) = (λ f df' j => ((kron i j) * df' : X))
:= sorry


@[simp low]
theorem parm.arg_x.adjDiff_simp
  (f : X → ι → Z) [IsSmooth f] [∀ x, HasAdjoint $ δ f x] (i : ι)
  : δ† (λ x => f x i) = (λ x dx' => (δ† f x) (λ j => ((kron i j) * dx' : Z)))
:= 
by 
  rw [comp.arg_x.adjDiff_simp (λ (x : ι → Z) => x i) f]
  simp


--------------------------------------------------------
-- These theorems are problematic when used with simp --


@[simp low-1]
theorem comp.arg_x.parm1.adjDiff_simp
  (a : α) 
  (f : Y → α → Z) [IsSmooth f] [∀ y, HasAdjoint (λ dy => δ f y dy a)]
  (g : X → Y) [IsSmooth g] [∀ x, HasAdjoint $ δ g x] 
  : 
    δ† (λ x => f (g x) a) = λ x dx' => (δ† g x) ((δ† (hold λ y => f y a)) (g x) dx')
:= by 
  simp[adjDiff]; unfold hold; simp; done

example
  (a : α) 
  (f : Y → α → Z) [IsSmooth f] [∀ y, HasAdjoint (λ dy => δ f y dy a)]
  (g : X → Y) [IsSmooth g] [∀ x, HasAdjoint $ δ g x] 
  : 
    δ† (λ x => f (g x) a) = λ x dx' => (δ† g x) ((δ† (λ y => f y a)) (g x) dx')
:= by simp done

@[simp low-1]
theorem comp.arg_x.parm2.adjDiff_simp
  (a : α) (b : β)
  (f : Y → α → β → Z) [IsSmooth f] [∀ y, HasAdjoint (λ dy => δ f y dy a b)]
  (g : X → Y) [IsSmooth g] [∀ x, HasAdjoint $ δ g x] 
  : 
    δ† (λ x => f (g x) a b) = λ x dx' => (δ† g x) ((δ† (hold λ y => f y a b)) (g x) dx')
:= by 
  simp[adjDiff]; unfold hold; simp; done

@[simp low-1]
theorem comp.arg_x.parm3.adjDiff_simp
  (a : α) (b : β) (c : γ)
  (f : Y → α → β → γ → Z) [IsSmooth f] [∀ y, HasAdjoint (λ dy => δ f y dy a b c)]
  (g : X → Y) [IsSmooth g] [∀ x, HasAdjoint $ δ g x] 
  : 
    δ† (λ x => f (g x) a b c) = λ x dx' => (δ† g x) ((δ† (hold λ y => f y a b c)) (g x) dx')
:= by 
  simp[adjDiff]; unfold hold; simp; done


@[simp low-1] -- try to avoid using this theorem
theorem diag.arg_x.parm1.adjDiff_simp
  (a : α)
  (f : Y₁ → Y₂ → α → Z) [IsSmooth f] [∀ y₁, IsSmooth (f y₁)] 
  [∀ y₁ y₂, HasAdjoint (λ dy₁ => δ f y₁ dy₁ y₂ a)]
  [∀ y₁ y₂, HasAdjoint (λ dy₂ => δ (f y₁) y₂ dy₂ a)]
  (g₁ : X → Y₁) [IsSmooth g₁] [∀ x, HasAdjoint (δ g₁ x)]
  (g₂ : X → Y₂) [IsSmooth g₂] [∀ x, HasAdjoint (δ g₂ x)]
  : δ† (λ x => f (g₁ x) (g₂ x) a)
    = 
    λ x dx' => 
      (δ† g₁ x) ((δ† (hold λ y₁ => f y₁ (g₂ x) a)) (g₁ x) dx')
      +
      (δ† g₂ x) ((δ† (hold λ y₂ => f (g₁ x) y₂ a)) (g₂ x) dx')
:= by 
  have inst : HasAdjoint (λ yy : Z × Z => yy.1 + yy.2) := sorry
  simp[adjDiff]; unfold hold; simp; unfold hold; admit


@[simp low-1] -- try to avoid using this theorem
theorem diag.arg_x.parm2.adjDiff_simp
  (a : α) (b : β)
  (f : Y₁ → Y₂ → α → β → Z) [IsSmooth f] [∀ y₁, IsSmooth (f y₁)] 
  [∀ y₁ y₂, HasAdjoint (λ dy₁ => δ f y₁ dy₁ y₂ a b)]
  [∀ y₁ y₂, HasAdjoint (λ dy₂ => δ (f y₁) y₂ dy₂ a b)]
  (g₁ : X → Y₁) [IsSmooth g₁] [∀ x, HasAdjoint (δ g₁ x)]
  (g₂ : X → Y₂) [IsSmooth g₂] [∀ x, HasAdjoint (δ g₂ x)]
  : δ† (λ x => f (g₁ x) (g₂ x) a b) 
    = 
    λ x dx' => 
      (δ† g₁ x) ((δ† (hold λ y₁ => f y₁ (g₂ x) a b)) (g₁ x) dx')
      +
      (δ† g₂ x) ((δ† (hold λ y₂ => f (g₁ x) y₂ a b)) (g₂ x) dx')
:= by 
  have inst : HasAdjoint (λ yy : Z × Z => yy.1 + yy.2) := sorry
  simp[adjDiff]; unfold hold; simp; unfold hold; admit


@[simp low-1] -- try to avoid using this theorem
theorem diag.arg_x.parm3.adjDiff_simp
  (a : α) (b : β) (c : γ)
  (f : Y₁ → Y₂ → α → β → γ → Z) [IsSmooth f] [∀ y₁, IsSmooth (f y₁)] 
  [∀ y₁ y₂, HasAdjoint (λ dy₁ => δ f y₁ dy₁ y₂ a b c)]
  [∀ y₁ y₂, HasAdjoint (λ dy₂ => δ (f y₁) y₂ dy₂ a b c)]
  (g₁ : X → Y₁) [IsSmooth g₁] [∀ x, HasAdjoint (δ g₁ x)]
  (g₂ : X → Y₂) [IsSmooth g₂] [∀ x, HasAdjoint (δ g₂ x)]
  : δ† (λ x => f (g₁ x) (g₂ x) a b c) 
    = 
    λ x dx' => 
      (δ† g₁ x) ((δ† (hold λ y₁ => f y₁ (g₂ x) a b c)) (g₁ x) dx')
      +
      (δ† g₂ x) ((δ† (hold λ y₂ => f (g₁ x) y₂ a b c)) (g₂ x) dx')
:= by 
  have inst : HasAdjoint (λ yy : Z × Z => yy.1 + yy.2) := sorry
  simp[adjDiff]; unfold hold; simp; unfold hold; admit