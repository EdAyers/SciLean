import SciLean.Core.Fun.Diff
import SciLean.Core.Fun.Adjoint
import SciLean.Core.Mor.HasAdjDiff

namespace SciLean


variable {α β γ : Type}
variable {X Y Z : Type} [SemiHilbert X] [SemiHilbert Y] [SemiHilbert Z] 
variable {Y₁ Y₂ : Type} [SemiHilbert Y₁] [SemiHilbert Y₂]
variable {ι : Type} [Enumtype ι]

-- noncomputable 
-- def adjDiff
--   (f : X → Y) (x : X) : Y → X := (∂ f x)†

class AdjointDifferential (Fun : Type) (Diff : outParam Type) where
  adjointDifferential : Fun → Diff

export AdjointDifferential (adjointDifferential)

@[default_instance]
noncomputable
instance : AdjointDifferential (X → Y) (X → Y → X) where
  adjointDifferential f x := (∂ f x)†

prefix:max "∂†" => adjointDifferential
macro "∂†" x:Lean.Parser.Term.funBinder "," f:term:66 : term => `(∂† λ $x => $f)

class Gradient (Fun : Type) (Diff : outParam Type) where
  gradient : Fun → Diff

@[default_instance]
noncomputable
instance [One Y] : Gradient (X → Y) (X → X) where
  gradient f := λ x => ∂† f x 1

export Gradient (gradient)

prefix:max "∇" => gradient

-- Notation 
-- ⅆ s, f s         --> ⅆ λ s => f s
-- ⅆ s : ℝ, f s     --> ⅆ λ s : ℝ => f s
-- ⅆ s := t, f s    --> (ⅆ λ s => f s) t
syntax "∇" diffBinder "," term:66 : term
syntax "∇" "(" diffBinder ")" "," term:66 : term
macro_rules 
| `(∇ $x:ident, $f) =>
  `(∇ λ $x => $f)
| `(∇ $x:ident : $type:term, $f) =>
  `(∇ λ $x : $type => $f)
| `(∇ $x:ident := $val:term, $f) =>
  `((∇ λ $x => $f) $val)
| `(∇ ($b:diffBinder), $f) =>
  `(∇ $b, $f)

@[simp]
theorem gradient_is_adjDiff (f : X → ℝ) 
  : ∇ f = λ x => ∂† f x 1 := by rfl

instance (f : X → Y) [HasAdjDiff f] (x : X) : IsLin (∂† f x) := sorry

----------------------------------------------------------------------


@[simp ↓]
theorem id.arg_x.adjDiff_simp
  : ∂† (λ x : X => x) = λ x dx => dx := by simp[adjointDifferential]; done

@[simp ↓]
theorem const.arg_x.adjDiff_simp 
  : ∂† (λ (x : X) (i : ι) => x) = λ x f => ∑ i, f i := by simp[adjointDifferential]; done

@[simp ↓]
theorem const.arg_y.adjDiff_simp (x : X)
  : ∂† (λ (y : Y) => x) = (λ y dy' => (0 : Y)) := by simp[adjointDifferential]; done

@[simp ↓ low-4]
theorem swap.arg_y.adjDiff_simp
  (f : ι → X → Z) [inst : ∀ i, HasAdjDiff (f i)]
  : ∂† (λ x y => f y x) = (λ x dx' => ∑ i, (∂† (f i) x) (dx' i)) := 
by 
  have isf := λ i => (inst i).isSmooth
  have iaf := λ i => (inst i).hasAdjDiff

  simp[adjointDifferential]; done

@[simp ↓ low-3]
theorem subst.arg_x.adjDiff_simp
  (f : X → Y → Z) [IsSmooth f]
  [instfx : ∀ y, HasAdjDiff λ x => f x y]
  [instfy : ∀ x, HasAdjDiff (f x)]
  (g : X → Y) [instg : HasAdjDiff g]
  : ∂† (λ x => f x (g x)) 
    = 
    λ x dx' => 
      (∂† (hold λ x' => f x' (g x))) x dx'
      +
      (∂† g x) (∂† (f x) (g x) dx')
    := 
by 
  have isfx := λ y => (instfx y).isSmooth
  have iafx := λ y => (instfx y).hasAdjDiff
  have isfy := λ x => (instfy x).isSmooth
  have iafy := λ x => (instfy x).hasAdjDiff
  have isg := instg.isSmooth
  have iag := instg.hasAdjDiff

  simp at iafx
  simp at iafy

  funext x dx';
  -- have adjAdd : ∀ {X} [SemiHilbert X], HasAdjoint fun yy : X×X => yy.fst + yy.snd := sorry
  simp[adjointDifferential] --- bla bla bla
  admit


@[simp ↓ low-2]
theorem subst.arg_x.parm1.adjDiff_simp
  (a : α)
  (f : X → Y → α → Z) [IsSmooth λ x y => f x y a]
  [instfx : ∀ y, HasAdjDiff λ x => f x y a]
  [instfy : ∀ x, HasAdjDiff λ y => f x y a]
  (g : X → Y) [instg : HasAdjDiff g]
  : ∂† (λ x => f x (g x) a) 
    = 
    λ x dx' => 
      (∂† (hold λ x' => f x' (g x) a)) x dx'
      +
      (∂† g x) (∂† (hold λ y => f x y a) (g x) dx')
    := 
by 
  apply subst.arg_x.adjDiff_simp (λ x y => f x y a) g
  done

@[simp ↓ low-2]
theorem subst.arg_x.parm2.adjDiff_simp
  (a : α) (b : β)
  (f : X → Y → α → β → Z) [IsSmooth λ x y => f x y a b]
  [instfx : ∀ y, HasAdjDiff λ x => f x y a b]
  [instfy : ∀ x, HasAdjDiff λ y => f x y a b]
  (g : X → Y) [instg : HasAdjDiff g]
  : ∂† (λ x => f x (g x) a b) 
    = 
    λ x dx' => 
      (∂† (hold λ x' => f x' (g x) a b)) x dx'
      +
      (∂† g x) (∂† (hold λ y => f x y a b) (g x) dx')
    := 
by 
  apply subst.arg_x.adjDiff_simp (λ x y => f x y a b) g
  done

@[simp ↓ low-2]
theorem subst.arg_x.parm3.adjDiff_simp
  (a : α) (b : β) (c : γ)
  (f : X → Y → α → β → γ → Z) [IsSmooth λ x y => f x y a b c]
  [instfx : ∀ y, HasAdjDiff λ x => f x y a b c]
  [instfy : ∀ x, HasAdjDiff λ y => f x y a b c]
  (g : X → Y) [instg : HasAdjDiff g]
  : ∂† (λ x => f x (g x) a b c) 
    = 
    λ x dx' => 
      (∂† (hold λ x' => f x' (g x) a b c)) x dx'
      +
      (∂† g x) (∂† (hold λ y => f x y a b c) (g x) dx')
    := 
by 
  apply subst.arg_x.adjDiff_simp (λ x y => f x y a b c) g
  done

@[simp ↓ low-1]
theorem comp.arg_x.adjDiff_simp
  (f : Y → Z) [instf : HasAdjDiff f] --[IsSmooth f] [∀ y, HasAdjoint $ ∂ f y] 
  (g : X → Y) [instg : HasAdjDiff g] -- [IsSmooth g] [∀ x, HasAdjoint $ ∂ g x] 
  : ∂† (λ x => f (g x)) = λ x dx' => (∂† g x) ((∂† f (g x)) dx') := 
by 
  simp; unfold hold; simp
  done

@[simp ↓ low-2]
theorem diag.arg_x.adjDiff_simp
  (f : Y₁ → Y₂ → Z) [IsSmooth f]
  [∀ y₂, HasAdjDiff λ y₁ => f y₁ y₂]
  [∀ y₁, HasAdjDiff λ y₂ => f y₁ y₂]
  (g₁ : X → Y₁) [hg : HasAdjDiff g₁]
  (g₂ : X → Y₂) [HasAdjDiff g₂]
  : ∂† (λ x => f (g₁ x) (g₂ x)) 
    = 
    λ x dx' => 
      (∂† g₁ x) ((∂† λ y₁ => f y₁ (g₂ x)) (g₁ x) dx')
      +
      (∂† g₂ x) ((∂† λ y₂ => f (g₁ x) y₂) (g₂ x) dx')
    := 
by 
  have sg := hg.1
  simp; unfold hold; simp; unfold hold; simp; done

@[simp ↓ low]
theorem eval.arg_f.adjDiff_simp
  (i : ι)
  : ∂† (λ (f : ι → X) => f i) = (λ f df' j => ((kron i j) * df' : X))
:= sorry

@[simp ↓ low-1]
theorem eval.arg_x.parm1.adjDiff_simp
  (f : X → ι → Z) [HasAdjDiff f]
  : ∂† (λ x => f x i) = (λ x dx' => (∂† f x) (λ j => ((kron i j) * dx' : Z)))
:= 
by 
  rw [comp.arg_x.adjDiff_simp (λ (x : ι → Z) => x i) f]
  simp


--------------------------------------------------------
-- These theorems are problematic when used with simp --


@[simp ↓ low-1]
theorem comp.arg_x.parm1.adjDiff_simp
  (a : α) 
  (f : Y → α → Z) [HasAdjDiff λ y => f y a]
  (g : X → Y) [HasAdjDiff g]
  : 
    ∂† (λ x => f (g x) a) = λ x dx' => (∂† g x) ((∂† (hold λ y => f y a)) (g x) dx')
:= by 
  simp; unfold hold; simp
  done

@[simp ↓ low-1]
theorem comp.arg_x.parm2.adjDiff_simp
  (a : α) (b : β)
  (f : Y → α → β → Z) [HasAdjDiff λ y => f y a b]
  (g : X → Y) [HasAdjDiff g]
  : 
    ∂† (λ x => f (g x) a b) = λ x dx' => (∂† g x) ((∂† (hold λ y => f y a b)) (g x) dx')
:= by 
  simp; unfold hold; simp
  done

@[simp ↓ low-1]
theorem comp.arg_x.parm3.adjDiff_simp
  (a : α) (b : β) (c : γ)
  (f : Y → α → β → γ → Z) [HasAdjDiff λ y => f y a b c]
  (g : X → Y) [HasAdjDiff g]
  : 
    ∂† (λ x => f (g x) a b c) = λ x dx' => (∂† g x) ((∂† (hold λ y => f y a b c)) (g x) dx')
:= by 
  simp; unfold hold; simp
  done

example (a : α) (f : Y₁ → Y₂ → α → Z) [IsSmooth λ y₁ y₂ => f y₁ y₂ a]
  (g₁ : X → Y₁) [hg : IsSmooth g₁] : IsSmooth (λ x y => f (g₁ x) y a) := by infer_instance


@[simp ↓ low-1] -- try to avoid using this theorem
theorem diag.arg_x.parm1.adjDiff_simp
  (a : α)
  (f : Y₁ → Y₂ → α → Z) [IsSmooth λ y₁ y₂ => f y₁ y₂ a]
  [∀ y₂, HasAdjDiff λ y₁ => f y₁ y₂ a]
  [∀ y₁, HasAdjDiff λ y₂ => f y₁ y₂ a]
  (g₁ : X → Y₁) [hg : HasAdjDiff g₁]
  (g₂ : X → Y₂) [HasAdjDiff g₂]
  : ∂† (λ x => f (g₁ x) (g₂ x) a)
    = 
    λ x dx' => 
      (∂† g₁ x) ((∂† (hold λ y₁ => f y₁ (g₂ x) a)) (g₁ x) dx')
      +
      (∂† g₂ x) ((∂† (hold λ y₂ => f (g₁ x) y₂ a)) (g₂ x) dx')
:= by 
  have sg := hg.1

  admit
  
@[simp ↓ low-1] -- try to avoid using this theorem
theorem diag.arg_x.parm2.adjDiff_simp
  (a : α) (b : β)
  (f : Y₁ → Y₂ → α → β → Z) [IsSmooth λ y₁ y₂ => f y₁ y₂ a b]
  [∀ y₂, HasAdjDiff λ y₁ => f y₁ y₂ a b]
  [∀ y₁, HasAdjDiff λ y₂ => f y₁ y₂ a b]
  (g₁ : X → Y₁) [HasAdjDiff g₁]
  (g₂ : X → Y₂) [HasAdjDiff g₂]
  : ∂† (λ x => f (g₁ x) (g₂ x) a b)
    = 
    λ x dx' => 
      (∂† g₁ x) ((∂† (hold λ y₁ => f y₁ (g₂ x) a b)) (g₁ x) dx')
      +
      (∂† g₂ x) ((∂† (hold λ y₂ => f (g₁ x) y₂ a b)) (g₂ x) dx')
:= by 
  (apply diag.arg_x.adjDiff_simp (λ y₁ y₂ => f y₁ y₂ a b) g₁ g₂)
  done

@[simp ↓ low-1] -- try to avoid using this theorem
theorem diag.arg_x.parm3.adjDiff_simp
  (a : α) (b : β) (c : γ)
  (f : Y₁ → Y₂ → α → β → γ → Z) [IsSmooth λ y₁ y₂ => f y₁ y₂ a b c]
  [∀ y₂, HasAdjDiff λ y₁ => f y₁ y₂ a b c]
  [∀ y₁, HasAdjDiff λ y₂ => f y₁ y₂ a b c]
  (g₁ : X → Y₁) [HasAdjDiff g₁]
  (g₂ : X → Y₂) [HasAdjDiff g₂]
  : ∂† (λ x => f (g₁ x) (g₂ x) a b c)
    = 
    λ x dx' => 
      (∂† g₁ x) ((∂† (hold λ y₁ => f y₁ (g₂ x) a b c)) (g₁ x) dx')
      +
      (∂† g₂ x) ((∂† (hold λ y₂ => f (g₁ x) y₂ a b c)) (g₂ x) dx')
:= by 
  (apply diag.arg_x.adjDiff_simp (λ y₁ y₂ => f y₁ y₂ a b c) g₁ g₂)
  done

----------------------------------------------------------------------


-- @[simp ↓]
-- theorem subst.arg_x.adjDiff_simp'''
--   (f : X → Y → Z) [IsSmooth f]
--   [instfx : ∀ y, HasAdjDiff λ x => f x y]
--   [instfy : ∀ x, HasAdjDiff (f x)]
--   (g : Y → X) [instg : HasAdjDiff g]
--   : ∂† (λ y => f (g y) y) 
--     = 
--     λ y dy' => 
--       (∂† (λ y' => f (g y) y')) y dy'
--       +
--       (∂† g y) (∂† (λ x => f x y) (g y) dy')
--     := 
-- by 
--   sorry




