import Lean
import Lean.Meta.Basic
import Lean.Elab.Tactic.Basic
import Lean.Elab.Tactic.ElabTerm
import Lean.Elab.Tactic.Conv.Basic

import SciLean.Functions.Limit

open Lean 
open Lean.Meta
open Lean.Elab.Tactic

namespace BubbleLimit

partial def replaceSubExpression (e : Expr) (test : Expr → Bool) (replace : Expr → MetaM Expr) : MetaM Expr := do
if (test e) then
  (replace e)
else
match e with
  | Expr.app f x => do pure (mkApp (← (replaceSubExpression f test replace)) (← (replaceSubExpression x test replace)))
  | Expr.lam n x b _ => pure $ mkLambda n e.binderInfo x (← replaceSubExpression b test replace)
  | _ => pure e

-- use 
def getlimit  (e : Expr) : MetaM Expr := do
  withLocalDecl `n default (mkConst `Nat) λ n => do
    let test := (λ e : Expr => 
      match e.getAppFn.constName? with
        | some name => name == ``SciLean.limit
        | none => false)
    let replace := (λ e : Expr => 
      do
        let lim := e.getAppArgs[1]!
        let args := #[n].append e.getAppArgs[2:]
        mkAppM' lim args)
    mkLambdaFVars #[n] (← replaceSubExpression e test replace)
  

def bubbleLimitCore (mvarId : MVarId) : MetaM (List MVarId) :=
  mvarId.withContext do
    let tag      ← mvarId.getTag
    let target   ← mvarId.getType

    -- Check if target is actually `Approx spec`
    let spec := target.getAppArgs[1]!
    let lim ← getlimit spec

    let new_spec ← mkAppM `SciLean.limit #[lim]
    let new_target ← mkAppM `SciLean.Approx #[new_spec]
    let new_mvar  ← mkFreshExprSyntheticOpaqueMVar new_target tag
    let eq       ← mkEq new_target target
    let eq_mvar  ← mkFreshExprSyntheticOpaqueMVar eq

    mvarId.assign (← mkAppM `Eq.mp #[eq_mvar, new_mvar])

    return [eq_mvar.mvarId!, new_mvar.mvarId!]  

syntax (name := bubble_limit) "bubble_limit": tactic

@[tactic bubble_limit] def tacticBubbleLimit : Tactic
| `(tactic| bubble_limit) => do 
          let mainGoal ← getMainGoal
          let todos ← bubbleLimitCore mainGoal
          setGoals todos
          pure ()
| _ => Lean.Elab.throwUnsupportedSyntax


syntax (name := bubble_lim) "bubble_lim": conv

open Conv

@[tactic bubble_lim] def tacticBubbleLim : Tactic
| `(conv| bubble_lim) => do  
  (← getMainGoal).withContext do
    let lhs ← getLhs
    let f ← getlimit lhs
    let lhs' ← mkAppM `SciLean.limit #[f]

    let eqGoal ← mkFreshExprSyntheticOpaqueMVar (← mkEq lhs lhs')

    updateLhs lhs' eqGoal
    replaceMainGoal [eqGoal.mvarId!, (← getMainGoal)]
| _ => Lean.Elab.throwUnsupportedSyntax

end BubbleLimit
  
